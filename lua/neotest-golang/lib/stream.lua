local colorize = require("neotest-golang.lib.colorize")
local convert = require("neotest-golang.lib.convert")
local json = require("neotest-golang.lib.json")
local logger = require("neotest-golang.logging")
local mapping = require("neotest-golang.lib.mapping")
local options = require("neotest-golang.options")
local patterns = require("neotest-golang.lib.patterns")

local async = require("neotest.async")
local neotest_lib = require("neotest.lib")

local M = {}

---@enum processingStatus
M.ProcessingStatus = {
  streaming = "streaming",
  status_detected = "status_detected",
}

--- Internal test metadata, required for processing.
--- @class TestMetadata
--- @field position_id? string The neotest position ID for this test
--- @field output_parts string[] Raw output parts collected during streaming
--- @field output_path? string Path to the finalized output file
--- @field status? processingStatus Whether the test result has been finalized

--- The accumulated test data. This holds both the Neotest result for the test and also internal metadata.
--- @class TestEntry
--- @field result neotest.Result The neotest result data
--- @field metadata TestMetadata Custom metadata for processing

--- The `go test -json` event structure.
--- @class GoTestEvent
--- @field Time? string ISO 8601 timestamp when the event occurred
--- @field Action "start"|"run"|"output"|"build-output"|"skip"|"fail"|"pass" Test action
--- @field Package? string Package name being tested
--- @field Test? string Test name (present when Action relates to a specific test)
--- @field Elapsed? number Time elapsed in seconds
--- @field Output? string Output text (present when Action is "output")

---@type table<string, neotest.Result>
M.cached_results = {}

--- Contstructor for new stream.
--- @param golist_data table Golist data containing package information
---@param json_filepath string|nil Path to the JSON output file
---@return function, function
function M.new(tree, golist_data, json_filepath)
  M.cached_results = {} -- reset
  local stream_data = function() end -- no-op
  local stop_stream = function() end -- no-op
  if options.get().runner == "gotestsum" then
    if json_filepath ~= nil then
      neotest_lib.files.write(json_filepath, "") -- ensure the file exists
      stream_data, stop_stream = neotest_lib.files.stream_lines(json_filepath)
    else
      logger.error("JSON filepath is required for gotestsum runner streaming")
    end
  end

  --- Stream function.
  ---@param data function A function that returns a table of strings, each representing a line of JSON output.
  local function stream(data)
    local json_lines = {}

    ---@type table<string, TestEntry>
    local accum = {}
    ---@type table<string, neotest.Result>
    local results = {}

    -- Build position lookup table once for O(1) mapping performance
    local position_lookup = mapping.build_position_lookup(tree, golist_data)
    logger.debug(
      "Built position lookup with "
        .. vim.tbl_count(position_lookup)
        .. " mappings"
    )

    return function()
      local lines = {}
      if options.get().runner == "go" then
        lines = data() -- capture from stdout
      elseif options.get().runner == "gotestsum" then
        lines = stream_data() or {} -- capture from stream
      end

      json_lines = json.decode_from_table(lines, true)

      for _, json_line in ipairs(json_lines) do
        accum =
          M.process_event(tree, golist_data, accum, json_line, position_lookup)
      end

      results = M.make_stream_results(accum)

      -- TODO: optimize caching:
      -- 1. Direct cache population in make_stream_results:
      --    M.cached_results = process.make_stream_results_and_cache(accum, M.cached_results)
      -- 2. Eliminate intermediate results table (eliminates the pairs loop).
      -- 3. Lazy file writing?
      --    - Defer file writing until final test_results() phase (maybe opt-in to write during stream?)
      --    - Keep output_parts in memory during streaming.
      --    - Write files only when actually needed (reduces i/o).
      -- 4. Cache transfer instead of clear:
      --    Instead of: load -> clear -> rebuild
      --    Do: transfer ownership
      --    local results = M.transfer_cached_results() -- returns and clears in one operation
      for pos_id, result in pairs(results) do
        M.cached_results[pos_id] = result
      end

      return results
    end
  end

  return stream, stop_stream
end

--- Process a single event from the test output.
--- @param tree neotest.Tree The neotest tree structure
--- @param golist_data table The 'go list -json' output
--- @param accum table<string, TestEntry> Accumulated test data.
--- @param e GoTestEvent The event data.
--- @param position_lookup table<string, string> Position lookup table for O(1) mapping
--- @return table<string, TestEntry>
-- TODO: this is part of streaming hot path. To be optimized.
function M.process_event(tree, golist_data, accum, e, position_lookup)
  if e.Package then
    local id = e.Package or "UNKNOWN_PACKAGE"
    accum = M.process_package(tree, golist_data, accum, e, id)
  end

  if e.Package and e.Test then
    local id = e.Package .. "::" .. e.Test
    accum = M.process_test(tree, golist_data, accum, e, id, position_lookup)
  end

  return accum
end

--- Process package events
--- @param tree neotest.Tree The neotest tree structure
--- @param golist_data table The 'go list -json' output
--- @param accum table<string, TestEntry> Accumulated test data
--- @param e GoTestEvent The event data
--- @param id string Package ID
--- @return table<string, TestEntry>
-- TODO: this is part of streaming hot path. To be optimized.
function M.process_package(tree, golist_data, accum, e, id)
  -- Indicate package started/running.
  if not accum[id] and (e.Action == "start" or e.Action == "run") then
    accum[id] = {
      result = {
        status = "skipped",
        output = "",
        errors = {},
      },
      metadata = {
        status = "streaming",
        output_parts = {},
      },
    }
    if e.Output then
      table.insert(accum[id].metadata.output_parts, e.Output)
    end
  end

  -- Record output for package.
  if
    accum[e.Package].metadata.status == "streaming" and e.Action == "output"
  then
    if e.Output then
      table.insert(accum[id].metadata.output_parts, e.Output)
    end
  end

  -- Record build output for test (introduced in Go 1.24).
  if
    accum[id].metadata.status == "streaming" and e.Action == "build-output"
  then
    vim.notify(vim.inspect(e)) -- TODO: what to do with build-output?
    -- NOTE: "build-fail" message indicate build error.
    if e.Output then
      table.insert(accum[id].metadata.output_parts, e.Output)
    end
  end

  -- Register package results.
  if
    accum[e.Package].metadata.status == "streaming"
    and (e.Action == "pass" or e.Action == "fail" or e.Action == "skip")
  then
    if e.Action == "pass" then
      accum[id].result.status = "passed"
    elseif e.Action == "fail" then
      accum[id].result.status = "failed"
    else
      accum[id].result.status = "skipped"
    end

    accum[id].metadata.status = "status_detected"

    if e.Output then
      -- NOTE: this does not ever happen, it seems.
      table.insert(accum[id].metadata.output_parts, e.Output)
    end

    accum[id].metadata.position_id =
      convert.to_dir_position_id(golist_data, e.Package)
  end
  return accum
end

--- Process test events
--- @param tree neotest.Tree The neotest tree structure
--- @param golist_data table The 'go list -json' output
--- @param accum table<string, TestEntry> Accumulated test data
--- @param e GoTestEvent The event data
--- @param id string Test ID
--- @param position_lookup table<string, string> Position lookup table for O(1) mapping
--- @return table<string, TestEntry>
-- TODO: this is part of streaming hot path. To be optimized.
function M.process_test(tree, golist_data, accum, e, id, position_lookup)
  -- Indicate test started/running.
  if not accum[id] and e.Action == "run" then
    accum[id] = {
      result = {
        status = "skipped",
        output = "",
        errors = {},
      },
      metadata = {
        status = "streaming",
        output_parts = {},
      },
    }
    if e.Output then
      table.insert(accum[id].metadata.output_parts, e.Output)
    end
  end

  -- Record output for test.
  if accum[id].metadata.status == "streaming" and e.Action == "output" then
    if e.Output then
      table.insert(accum[id].metadata.output_parts, e.Output)
    end
  end

  -- Record build output for test (introduced in Go 1.24).
  if accum[id].metadata.status == "streaming" and e.Action == "build-output" then
    vim.notify(vim.inspect(e)) -- TODO: what to do with build-output?
    -- NOTE: "build-fail" message indicate build error.
    if e.Output then
      table.insert(accum[id].metadata.output_parts, e.Output)
    end
  end

  -- Register test results.
  if
    accum[id].metadata.status == "streaming"
    and (e.Action == "pass" or e.Action == "fail" or e.Action == "skip")
  then
    if e.Action == "pass" then
      accum[id].result.status = "passed"
    elseif e.Action == "fail" then
      accum[id].result.status = "failed"
    else
      accum[id].result.status = "skipped"
    end

    accum[id].metadata.status = "status_detected"

    if e.Output then
      -- NOTE: this does not ever happen, it seems.
      table.insert(accum[id].metadata.output_parts, e.Output)
    end

    local pos_id = convert.get_position_id(position_lookup, e.Package, e.Test)
    if pos_id then
      accum[id].metadata.position_id = pos_id
    else
      logger.debug(
        "Unable to find position id for test: " .. e.Package .. "::" .. e.Test
      )
    end
  end
  return accum
end

--- Process diagnostics from output parts (optimized version)
--- @param test_entry TestEntry Test entry with metadata containing output_parts
--- @return table[] Array of diagnostic errors
function M.process_diagnostics_from_parts(test_entry)
  if
    not test_entry.metadata.output_parts
    or #test_entry.metadata.output_parts == 0
  then
    return {}
  end

  local errors = {}
  local test_filename =
    M.extract_filename_from_pos_id(test_entry.metadata.position_id)
  local error_set = {}

  -- Process each output part directly
  for _, part in ipairs(test_entry.metadata.output_parts) do
    if part then
      -- Handle multi-line parts by splitting if needed
      local lines = vim.split(part, "\n", { trimempty = true })
      for _, line in ipairs(lines) do
        -- Use optimized single-pass pattern matching
        local diagnostic = patterns.parse_diagnostic_line(line)
        if diagnostic then
          -- Filter diagnostics by filename if we have both filenames
          local should_include_diagnostic = true
          if test_filename and diagnostic.filename then
            -- Only include diagnostic if it belongs to the test file
            should_include_diagnostic = (diagnostic.filename == test_filename)
          end

          if should_include_diagnostic then
            -- Create a unique key for duplicate detection
            local error_key = (diagnostic.line_number - 1)
              .. ":"
              .. diagnostic.message

            if not error_set[error_key] then
              error_set[error_key] = true
              table.insert(errors, {
                line = diagnostic.line_number - 1,
                message = diagnostic.message,
                severity = diagnostic.severity,
              })
            end
          end
        end
      end
    end
  end

  return errors
end

--- Process internal test data into Neotest results for stream.
---@param accum table<string, TestEntry> The accumulated test data to process
---@return table<string, neotest.Result>
-- TODO: this is part of streaming hot path. To be optimized.
function M.make_stream_results(accum)
  ---@type table<string, neotest.Result>
  local results = {}

  for _, test_entry in pairs(accum) do
    if test_entry.metadata.position_id ~= nil then
      if test_entry.metadata.output_path == nil then
        -- NOTE: finalizing has not been done yet for this position id.
        -- TODO: use explicit variable to denote processing state done/pending rather than output_path presence.

        -- Use optimized diagnostics processing if output_parts available
        if test_entry.metadata.output_parts then
          test_entry.result.errors =
            M.process_diagnostics_from_parts(test_entry)
        end

        test_entry.metadata.output_path = vim.fs.normalize(async.fn.tempname())

        local uv = vim.loop
        local stat = uv.fs_stat(test_entry.metadata.output_path)
        if not stat then
          -- file does not exist, let's write it
          if test_entry.metadata.output_parts then
            local output_lines =
              colorize.colorize_parts(test_entry.metadata.output_parts)
            async.fn.writefile(output_lines, test_entry.metadata.output_path)
            test_entry.metadata.output_parts = nil -- clean up parts to save memory
          end
        end
      end

      -- Create the final neotest.Result with the output path
      ---@type neotest.Result
      local result = {
        status = test_entry.result.status,
        output = test_entry.metadata.output_path,
        errors = test_entry.result.errors,
        -- TODO: add short
      }

      results[test_entry.metadata.position_id] = result
    end
  end

  return results
end

--- Extract the filename from a neotest position ID
--- @param pos_id string Position ID like "/path/to/file.go::TestName" or synthetic ID like "github.com/pkg::TestName"
--- @return string|nil Filename like "file.go" or nil if not a file path
function M.extract_filename_from_pos_id(pos_id)
  if not pos_id then
    return nil
  end

  -- Check if it looks like a file path (contains "/" and ends with ".go")
  local file_path = pos_id:match("^([^:]+)")
  if file_path and file_path:match("%.go$") and file_path:match("/") then
    -- Extract just the filename from the full path
    return file_path:match("([^/]+)$")
  end

  return nil
end

return M
