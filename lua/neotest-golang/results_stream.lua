--- This file handles real-time processing of Go test output during streaming.
--- It processes individual Go test events and accumulates results as tests run.
---
--- NOTE: you cannot notify (vim.notify) from this module, as it is executed asynchronously.
--- Also, log with care, as this is a hot path.

local colorize = require("neotest-golang.lib.colorize")
local convert = require("neotest-golang.lib.convert")
local diagnostics = require("neotest-golang.lib.diagnostics")
local mapping = require("neotest-golang.lib.mapping")
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
    accum[e.Package]
    and accum[e.Package].metadata.status == "streaming"
    and e.Action == "output"
  then
    if e.Output then
      table.insert(accum[id].metadata.output_parts, e.Output)
    end
  end

  -- Record build output for test (introduced in Go 1.24).
  if
    accum[id]
    and accum[id].metadata.status == "streaming"
    and e.Action == "build-output"
  then
    if e.Output then
      table.insert(accum[id].metadata.output_parts, e.Output)
    end
  end

  -- Record build failure (introduced in Go 1.24).
  if
    accum[id]
    and accum[id].metadata.status == "streaming"
    and e.Action == "build-fail"
  then
    -- TODO: what do do here?
  end

  -- Register package results.
  if
    accum[e.Package]
    and accum[e.Package].metadata.status == "streaming"
    and (e.Action == "pass" or e.Action == "fail" or e.Action == "skip")
  then
    if e.Action == "pass" then
      accum[id].result.status = "passed"
    elseif e.Action == "fail" then
      accum[id].result.status = "failed"
    else
      accum[id].result.status = "skipped"
    end

    accum[id].metadata.status = "streamed"

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
        status = "streaming",
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
    and accum[id].metadata.status == "streaming"
    and e.Action == "output"
  then
    if e.Output then
      table.insert(accum[id].metadata.output_parts, e.Output)
    end
  end

  -- Record build output for test (introduced in Go 1.24).
  if
    accum[id]
    and accum[id].metadata.status == "streaming"
    and e.Action == "build-output"
  then
    if e.Output then
      table.insert(accum[id].metadata.output_parts, e.Output)
    end
  end

  -- Record build failure (introduced in Go 1.24).
  if
    accum[id]
    and accum[id].metadata.status == "streaming"
    and e.Action == "build-fail"
  then
    -- TODO: what do do here?
  end

  -- Register test results.
  if
    accum[id]
    and accum[id].metadata.status == "streaming"
    and (e.Action == "pass" or e.Action == "fail" or e.Action == "skip")
  then
    if e.Action == "pass" then
      accum[id].result.status = "passed"
    elseif e.Action == "fail" then
      accum[id].result.status = "failed"
    else
      accum[id].result.status = "skipped"
    end

    accum[id].metadata.status = "streamed"

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

---Process internal test data into Neotest results for stream.
---@param accum table<string, TestEntry> The accumulated test data to process
---@return table<string, neotest.Result>
function M.make_stream_results(accum)
  ---@type table<string, neotest.Result>
  local results = {}

  for key, test_entry in pairs(accum) do
    if test_entry.metadata.position_id ~= nil then
      if test_entry.metadata.status ~= "finalized" then
        if test_entry.metadata.output_parts then
          test_entry.result.errors = diagnostics.process_diagnostics(test_entry)
        end

        test_entry.metadata.output_path = vim.fs.normalize(async.fn.tempname())

        local stat = vim.uv.fs_stat(test_entry.metadata.output_path)
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
      }

      test_entry.metadata.status = "finalized"
      accum[key] = test_entry

      results[test_entry.metadata.position_id] = result
    end
  end

  return results
end

return M
