local json = require("neotest-golang.lib.json")
local logger = require("neotest-golang.logging")
local mapping = require("neotest-golang.lib.mapping")
local options = require("neotest-golang.options")
local results_stream = require("neotest-golang.results_stream")
require("neotest-golang.lib.types")

local M = {}

---@type table<string, neotest.Result>
M.cached_results = {}

---Maximum cache size to prevent memory overflow
M.MAX_CACHE_SIZE = 10000

---Global stream strategy override for testing
---@type table|nil
M._test_stream_strategy = nil

---Track if streaming has been terminated
---@type boolean
M._stream_terminated = false

---Set a stream strategy override for testing purposes
---@param strategy table|nil The stream strategy to use, or nil to reset to default
function M.set_test_strategy(strategy)
  M._test_stream_strategy = strategy
end

---Reset stream termination flag
function M.reset_stream_state()
  M._stream_terminated = false
end

---Terminate streaming to prevent infinite loops
function M.terminate_stream()
  M._stream_terminated = true
end

---Atomically transfer ownership of cached results and clear the cache.
---This optimization eliminates the copy-then-clear pattern.
---@return table<string, neotest.Result>
function M.transfer_cached_results()
  local results = M.cached_results
  M.cached_results = {}
  M._stream_terminated = false -- Reset termination flag when transferring results
  return results
end

---Clean up cache if it exceeds maximum size
---Removes oldest entries to prevent memory overflow
function M.cleanup_cache_if_needed()
  local cache_size = vim.tbl_count(M.cached_results)
  if cache_size > M.MAX_CACHE_SIZE then
    logger.warn(
      "Cache size exceeded " .. M.MAX_CACHE_SIZE .. ", clearing oldest entries"
    )
    -- Clear half the cache to prevent frequent cleanup
    local entries_to_remove = math.floor(cache_size / 2)
    local removed = 0
    for key, _ in pairs(M.cached_results) do
      if removed >= entries_to_remove then
        break
      end
      M.cached_results[key] = nil
      removed = removed + 1
    end
  end
end

---Constructor for new stream.
---
--- This sets up Neotest output streaming based on selected runner and strategy.
--- The strategies supported are:
--- - Native live streaming via stdout (default for `go test -json`)
--- - Asynchronous file-based streaming (default for `gotestsum --jsonfile`)
--- - Synchronous file-based streaming (for testing purposes only)
---@param golist_data table Golist data containing package information
---@param json_filepath string|nil Path to the JSON output file
---@return function, function
function M.new(tree, golist_data, json_filepath)
  -- Reset stream state for new streaming session
  M.reset_stream_state()

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

  ---Stream function.
  ---@param data function A function that returns a table of strings, each representing a line output from stdout.
  local function stream(data)
    ---@type GoTestEvent[]
    local gotest_events = {}
    ---@type table<string, TestEntry>
    local accum = {}

    -- Track consecutive empty reads to detect completion
    local empty_reads = 0
    local max_empty_reads = 10

    -- Build position lookup table
    local lookup = mapping.build_position_lookup(tree, golist_data)
    logger.debug(
      "Built position lookup with " .. vim.tbl_count(lookup) .. " mappings"
    )

    return function()
      -- Check termination condition first
      if M._stream_terminated then
        logger.debug("Stream terminated, returning cached results")
        return M.cached_results
      end

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

      -- Track empty reads to detect completion
      if #lines == 0 then
        empty_reads = empty_reads + 1
        if empty_reads >= max_empty_reads then
          logger.debug(
            "No new data after "
              .. max_empty_reads
              .. " attempts, terminating stream"
          )
          M.terminate_stream()
          return M.cached_results
        end
        -- Return current cache without processing if no new data
        return M.cached_results
      else
        empty_reads = 0 -- Reset counter when we get data
      end

      ---@type GoTestEvent[]
      gotest_events = json.decode_from_table(lines, true)

      -- Process events in batches to prevent overwhelming the system
      local batch_size = 100
      local processed = 0
      for _, gotest_event in ipairs(gotest_events) do
        accum =
          results_stream.process_event(golist_data, accum, gotest_event, lookup)

        processed = processed + 1
        if processed >= batch_size then
          -- Yield control periodically for large batches
          break
        end
      end

      -- Clean up finalized entries from accum to prevent memory growth
      for id, test_entry in pairs(accum) do
        if test_entry.metadata.state == "finalized" then
          accum[id] = nil
        end
      end

      -- Optimized: Direct cache population eliminates intermediate results and copy loop
      results_stream.make_stream_results_with_cache(accum, M.cached_results)

      -- Clean up cache if it gets too large
      M.cleanup_cache_if_needed()

      -- Return the cache for compatibility with existing streaming interface
      return M.cached_results
    end
  end

  -- Override stop function to include stream termination
  local original_stop = stop_filestream
  local enhanced_stop = function()
    M.terminate_stream()
    original_stop()
  end

  return stream, enhanced_stop
end

return M
