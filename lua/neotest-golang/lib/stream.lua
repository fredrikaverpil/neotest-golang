local json = require("neotest-golang.lib.json")
local logger = require("neotest-golang.logging")
local mapping = require("neotest-golang.lib.mapping")
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

---Contstructor for new stream.
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

      for _, gotest_event in ipairs(gotest_events) do
        accum =
          results_stream.process_event(golist_data, accum, gotest_event, lookup)
      end

      -- Optimized: Direct cache population eliminates intermediate results and copy loop
      results_stream.make_stream_results_with_cache(accum, M.cached_results)

      -- TODO: optimize caching:
      -- 1. ✓ DONE - Direct cache population in make_stream_results:
      --    Updated streaming loop to use make_stream_results_with_cache()
      -- 2. ✓ DONE - Eliminate intermediate results table (eliminates the pairs loop).
      -- 3. Lazy file writing?
      --    - Defer file writing until final test_results() phase (maybe opt-in to write during stream?)
      --    - Keep output_parts in memory during streaming.
      --    - Write files only when actually needed (reduces i/o).
      -- 4. ✓ DONE - Cache transfer instead of clear:
      --    Implemented transfer_cached_results() for atomic ownership transfer

      -- Return the cache for compatibility with existing streaming interface
      return M.cached_results
    end
  end

  return stream, stop_filestream
end

return M
