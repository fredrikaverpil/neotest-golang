local json = require("neotest-golang.lib.json")
local logger = require("neotest-golang.lib.logging")
local mapping = require("neotest-golang.lib.mapping")
local metrics = require("neotest-golang.lib.metrics")
local options = require("neotest-golang.options")
local results_stream = require("neotest-golang.results_stream")
require("neotest-golang.lib.types")

local M = {}

---@type table<string, neotest.Result>
M.cached_results = {}

---Global stream strategy override for testing
---@type table|nil
M._test_stream_strategy = nil

---Set a stream strategy override for testing purposes
---@param strategy table|nil The stream strategy to use, or nil to reset to default
function M.set_test_strategy(strategy)
  M._test_stream_strategy = strategy
end

---Atomically transfer ownership of cached results and clear the cache.
---This optimization eliminates the copy-then-clear pattern.
---@return table<string, neotest.Result>
function M.transfer_cached_results()
  local results = M.cached_results
  M.cached_results = {}
  return results
end

---Create a new test result streaming processor.
---
---This function sets up real-time processing of Go test output with different strategies
---based on the selected test runner. The streaming processor handles Go test JSON events
---as they arrive and caches results for immediate feedback in Neotest.
---
---## Streaming Strategies
---
---**go test runner**: Uses stdout-based streaming where the `data` parameter from Neotest
---provides lines directly from the running `go test -json` process.
---
---**gotestsum runner**: Uses file-based streaming where gotestsum writes JSON events to
---a file (`--jsonfile`) and the processor reads from that file in real-time.
---
---**Test strategy override**: When `M._test_stream_strategy` is set (for integration tests),
---uses a custom strategy that reads from completed files synchronously.
---
---## Stream Function Behavior
---
---The returned stream function:
---- Processes Go test JSON events in real-time as they become available
---- Builds position lookup table mapping Go test names to Neotest position IDs
---- Accumulates test results and writes output files synchronously when tests complete
---- Returns cached results on each call for immediate UI updates
---- Handles empty data gracefully (returns current cache without processing)
---
---## Termination
---
---Streaming continues until the returned `stop_filestream` function is called,
---typically by `results_finalize.lua` when ready to aggregate final results.
---
---@param tree neotest.Tree The Neotest tree containing test positions
---@param golist_data table Output from `go list -json` containing package information
---@param json_filepath string|nil Path to gotestsum JSON output file (required for gotestsum runner)
---@return function stream_function Function that processes test events and returns cached results
---@return function stop_function Function to stop streaming and clean up resources
function M.new(tree, golist_data, json_filepath)
  -- Start performance monitoring session
  metrics.start_session()

  -- No-op filestream functions for gotestsum runner
  local filestream_data = function() end -- no-op
  local stop_filestream = function() end -- no-op

  -- Asynchronous file-based streaming strategy for gotestsum
  if not M._test_stream_strategy and options.get().runner == "gotestsum" then
    if not json_filepath then
      logger.error("JSON filepath is required for gotestsum runner streaming")
    end

    local live_strategy = require("neotest-golang.lib.stream_strategy.live")
    filestream_data, stop_filestream =
      live_strategy.create_stream(json_filepath)
  end

  -- Synchronous file-based streaming strategy override for testing
  if M._test_stream_strategy then
    if options.get().runner ~= "gotestsum" then
      logger.error(
        "Custom stream strategy can only be used with gotestsum runner"
      )
    end

    filestream_data, stop_filestream =
      M._test_stream_strategy.create_stream(json_filepath)
  end

  ---Stream function that processes test output in real-time.
  ---
  ---@param data function A function that returns a table of strings, each representing a line output from stdout.
  local function stream(data)
    ---@type GoTestEvent[]
    local gotest_events = {}
    ---@type table<string, TestEntry>
    local accum = {}

    -- Build position lookup table
    local lookup = mapping.build_position_lookup(tree, golist_data)
    logger.debug(
      "Built position lookup with " .. vim.tbl_count(lookup) .. " mappings"
    )

    return function()
      local lines = {}
      if options.get().runner == "go" then
        lines = data() -- capture `go test -json` output from stdout stream
      elseif options.get().runner == "gotestsum" then
        lines = filestream_data() or {} -- capture `go test -json` output from file stream

        -- Validate that we have data or file exists
        if #lines == 0 and json_filepath then
          local file_stat = vim.uv.fs_stat(json_filepath)
          if file_stat and file_stat.size > 0 then
            logger.debug(
              "Gotestsum file exists but no lines read yet, size: "
                .. file_stat.size
            )
          elseif not file_stat then
            logger.debug(
              "Gotestsum JSON file does not exist yet: " .. json_filepath
            )
          end
        elseif #lines > 0 then
          logger.debug("Gotestsum read " .. #lines .. " lines from file")
        end
      end

      ---@type GoTestEvent[]
      gotest_events = json.decode_from_table(lines, true)

      -- Process all events synchronously
      for _, gotest_event in ipairs(gotest_events) do
        -- Record event processing for metrics
        if gotest_event.Action then
          metrics.record_event(gotest_event.Action)
        end

        accum =
          results_stream.process_event(golist_data, accum, gotest_event, lookup)
      end

      -- Record memory usage metrics
      metrics.record_accum_size(vim.tbl_count(accum))
      metrics.record_cache_size(vim.tbl_count(M.cached_results))

      -- Optimized: Direct cache population eliminates intermediate results and copy loop
      results_stream.make_stream_results_with_cache(accum, M.cached_results)

      -- Return the cache for compatibility with existing streaming interface
      return M.cached_results
    end
  end

  return stream, stop_filestream
end

return M
