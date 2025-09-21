--- This file handles real-time processing of Go test output during streaming.
--- It processes individual Go test events and accumulates results as tests run.
---
--- NOTE: you cannot notify (vim.notify) from this module, as it is executed asynchronously.
--- Also, log with care, as this is a hot path.

local colorize = require("neotest-golang.lib.colorize")
local convert = require("neotest-golang.lib.convert")
local diagnostics = require("neotest-golang.lib.diagnostics")
local mapping = require("neotest-golang.lib.mapping")
local metrics = require("neotest-golang.lib.metrics")
require("neotest-golang.lib.types")

local async = require("neotest.async")

local M = {}

---Process a single event from the test output.
---@param golist_data table The 'go list -json' output
---@param accum table<string, TestEntry> Accumulated test data
---@param e GoTestEvent The event data.
---@param position_lookup table<string, string> Position lookup table
---@return table<string, TestEntry>
function M.process_event(golist_data, accum, e, position_lookup)
  if e.Package then
    local id = e.Package or "UNKNOWN_PACKAGE"
    accum = M.process_package(golist_data, accum, e, id)
  end

  if e.Package and e.Test then
    local id = e.Package .. "::" .. e.Test
    accum = M.process_test(accum, e, id, position_lookup)
  end

  return accum
end

---Process package events
---@param golist_data table The 'go list -json' output
---@param accum table<string, TestEntry> Accumulated test data
---@param e GoTestEvent The event data
---@param id string The internal test/package id
---@return table<string, TestEntry>
function M.process_package(golist_data, accum, e, id)
  -- Indicate package started/running.
  if not accum[id] and (e.Action == "start" or e.Action == "run") then
    accum[id] = {
      result = {
        status = "skipped", -- default to skipped until we know otherwise
        output = "",
        errors = {},
      },
      metadata = {
        state = "streaming",
        output_parts = {},
      },
    }
    if e.Output then
      table.insert(accum[id].metadata.output_parts, e.Output)
    end
  end

  -- Record output for package.
  if
    accum[e.Package]
    and accum[e.Package].metadata.state == "streaming"
    and e.Action == "output"
  then
    if e.Output then
      table.insert(accum[id].metadata.output_parts, e.Output)
    end
  end

  -- Record build output for test (introduced in Go 1.24).
  if
    accum[id]
    and accum[id].metadata.state == "streaming"
    and e.Action == "build-output"
  then
    -- NOTE: we don't care about e.Action == "build-fail" as we want to continue recording output
    if e.Output then
      table.insert(accum[id].metadata.output_parts, e.Output)
    end
  end

  -- Register package results.
  if
    accum[e.Package]
    and accum[e.Package].metadata.state == "streaming"
    and (e.Action == "pass" or e.Action == "fail" or e.Action == "skip")
  then
    if e.Action == "pass" then
      accum[id].result.status = "passed"
    elseif e.Action == "fail" then
      accum[id].result.status = "failed"
    else
      accum[id].result.status = "skipped"
    end

    accum[id].metadata.state = "streamed"

    if e.Output then
      -- NOTE: this does not ever happen, it seems.
      table.insert(accum[id].metadata.output_parts, e.Output)
    end

    accum[id].metadata.position_id =
      convert.to_dir_position_id(golist_data, e.Package)
  end
  return accum
end

---Process test events
---@param accum table<string, TestEntry> Accumulated test data
---@param e GoTestEvent The event data
---@param id string Test ID
---@param position_lookup table<string, string> Position lookup table for O(1) mapping
---@return table<string, TestEntry>
function M.process_test(accum, e, id, position_lookup)
  -- Indicate test started/running.
  if not accum[id] and e.Action == "run" then
    accum[id] = {
      result = {
        status = "skipped",
        output = "",
        errors = {},
      },
      metadata = {
        state = "streaming",
        output_parts = {},
      },
    }
    if e.Output then
      table.insert(accum[id].metadata.output_parts, e.Output)
    end
  end

  -- Record output for test.
  if
    accum[id]
    and accum[id].metadata.state == "streaming"
    and e.Action == "output"
  then
    if e.Output then
      table.insert(accum[id].metadata.output_parts, e.Output)
    end
  end

  -- Record build output for test (introduced in Go 1.24).
  if
    accum[id]
    and accum[id].metadata.state == "streaming"
    and e.Action == "build-output"
  then
    -- NOTE: we don't care about e.Action == "build-fail" as we want to continue recording output
    if e.Output then
      table.insert(accum[id].metadata.output_parts, e.Output)
    end
  end

  -- Register test results.
  if
    accum[id]
    and accum[id].metadata.state == "streaming"
    and (e.Action == "pass" or e.Action == "fail" or e.Action == "skip")
  then
    if e.Action == "pass" then
      accum[id].result.status = "passed"
    elseif e.Action == "fail" then
      accum[id].result.status = "failed"
    else
      accum[id].result.status = "skipped"
    end

    accum[id].metadata.state = "streamed"

    if e.Output then
      -- NOTE: this does not ever happen, it seems.
      table.insert(accum[id].metadata.output_parts, e.Output)
    end

    local pos_id = mapping.get_pos_id(position_lookup, e.Package, e.Test)
    if pos_id then
      accum[id].metadata.position_id = pos_id
    end
  end
  return accum
end

---Convert accumulated streaming test data into final Neotest results and update cache.
---
---This function processes test entries that have been accumulated during streaming and
---converts them into the final `neotest.Result` format that Neotest expects. It handles
---the critical transition from streaming internal format to Neotest's result format.
---
---## Processing Steps
---
---1. **Diagnostics Processing**: Extracts error information from test output using
---   the diagnostics module to create actionable error entries with line numbers.
---
---2. **Output File Creation**: For tests with captured output, creates temporary files
---   containing colorized test output. Files are written synchronously to ensure
---   immediate availability when results are cached.
---
---3. **Memory Management**: Clears `output_parts` arrays after successful file writes
---   to free memory and prevent accumulation during long streaming sessions.
---
---4. **Result Finalization**: Creates final `neotest.Result` objects with:
---   - Test status (passed/failed/skipped)
---   - Path to output file (nil if no output)
---   - Processed error diagnostics with line numbers
---
---5. **Cache Population**: Updates the provided cache directly with position ID as key,
---   enabling immediate result availability for Neotest UI updates.
---
---## Idempotency
---
---Only processes test entries that are not already "finalized", preventing duplicate
---processing and file creation if called multiple times with the same data.
---
---@param accum table<string, TestEntry> Accumulated test data from streaming (internal format)
---@param cache table<string, neotest.Result> The result cache to populate (Neotest format)
function M.make_stream_results_with_cache(accum, cache)
  for _, test_entry in pairs(accum) do
    if test_entry.metadata.position_id ~= nil then
      if test_entry.metadata.state ~= "finalized" then
        if test_entry.metadata.output_parts then
          test_entry.result.errors = diagnostics.process_diagnostics(test_entry)
        end

        -- Only generate output path and write when there's actual content
        if
          test_entry.metadata.output_parts
          and #test_entry.metadata.output_parts > 0
        then
          local temp_path = async.fn.tempname()
          if temp_path and temp_path ~= "" then
            test_entry.metadata.output_path = vim.fs.normalize(temp_path)

            -- Write file synchronously - ensures availability when result is cached
            local output_lines =
              colorize.colorize_parts(test_entry.metadata.output_parts)

            local success = pcall(
              async.fn.writefile,
              output_lines,
              test_entry.metadata.output_path
            )
            if not success then
              -- If file write fails, clear the output path so test still completes without output file
              test_entry.metadata.output_path = nil
            else
              -- Record successful file write for metrics
              local file_size = #table.concat(output_lines, "\n")
              metrics.record_file_write(file_size)
            end
          end
        end

        -- Clear output_parts after file write to prevent memory accumulation during long streaming sessions.
        -- Each output_parts array can contain hundreds of lines for verbose tests, and without cleanup
        -- these arrays remain in memory until the entire streaming session ends.
        if test_entry.metadata.output_parts then
          test_entry.metadata.output_parts = nil
        end
      end

      -- Create the final neotest.Result with the output path (only if exists)
      ---@type neotest.Result
      local result = {
        status = test_entry.result.status,
        output = test_entry.metadata.output_path, -- nil if no output parts
        errors = test_entry.result.errors,
      }

      test_entry.metadata.state = "finalized"
      cache[test_entry.metadata.position_id] = result
    end
  end
end

return M
