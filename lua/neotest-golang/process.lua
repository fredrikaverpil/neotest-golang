--- This file is centered around the parsing/processing of test execution output
--- and assembling of the final results to hand back over to Neotest.

local async = require("neotest.async")

local lib = require("neotest-golang.lib")
local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")

--- @class RunspecContext
--- @field pos_id string Neotest tree position id.
--- @field golist_data table<string, string> The 'go list' JSON data (lua table).
--- @field errors? table<string> Non-gotest errors to show in the final output.
--- @field is_dap_active boolean? If true, parsing of test output will occur.
--- @field test_output_json_filepath? string Gotestsum JSON filepath.
--- @field stop_stream fun() Stops the stream of test output.

--- @class TestData
--- @field status neotest.ResultStatus
--- @field short? string Shortened output string
--- @field errors? neotest.Error[]
--- @field neotest_data neotest.Position
--- @field gotest_data GoTestData
--- @field duplicate_test_detected boolean

--- @class GoTestData
--- @field name string Go test name.
--- @field pkg string Go package.
--- @field output? string[] Go test output.

local M = {}

--- Process the results from the test command.
--- @param spec neotest.RunSpec
--- @param result neotest.StrategyResult
--- @param tree neotest.Tree
--- @return table<string, neotest.Result>
function M.test_results(spec, result, tree)
  -- TODO: refactor this function into function calls; return_early, process_test_results, override_test_results.

  --- @type RunspecContext
  local context = spec.context

  --- @type neotest.Position
  local pos = tree:data()

  spec.context.stop_stream()

  --- Final Neotest results, the way Neotest wants it returned.
  --- @type table<string, neotest.Result>
  local neotest_result = {}

  if context.is_dap_active then
    -- return early if test result processing is not desired.
    neotest_result[context.pos_id] = {
      status = "skipped",
    }
    return neotest_result
  end

  --- The runner to use for running tests.
  --- @type string
  local runner = options.get().runner

  --- The raw output from the test command.
  --- @type table<string>
  local raw_output = async.fn.readfile(result.output)
  --- @type table<string>
  local runner_raw_output = {}
  if runner == "go" then
    runner_raw_output = raw_output
  elseif runner == "gotestsum" then
    if context.test_output_json_filepath == nil then
      logger.error("Gotestsum JSON output file not found.")
      return neotest_result
    end
    runner_raw_output = async.fn.readfile(context.test_output_json_filepath)
  end
  logger.debug({ "Runner '" .. runner .. "', raw output: ", runner_raw_output })

  --- The 'go list -json' output, converted into a lua table.
  local golist_output = context.golist_data

  --- Go test output.
  --- @type table
  local gotest_output = lib.json.decode_from_table(runner_raw_output, true)

  local accum = {}
  for _, json_line in ipairs(gotest_output) do
    accum = lib.stream.process_event(tree, golist_output, accum, json_line)
  end

  ---@type table<string, neotest.Result>
  local results = {}

  for _, test_data in pairs(accum) do
    if test_data.position_id ~= nil then
      local o =
        vim.split(M.colorizer(test_data.output), "\n", { trimempty = true })
      async.fn.writefile(o, test_data.output_path)

      results[test_data.position_id] = {
        status = test_data.status,
        output = test_data.output_path,
        -- TODO: add short
        -- TODO: add errors
      }
    end

    if pos.id == test_data.position_id and result.code ~= 0 then
      results[test_data.position_id].status = "failed"
    end
  end

  return results
end

--- Colorize the test output based on the test result.
---
--- It will colorize the test output line based on the test result (PASS - green, FAIL - red, SKIP - yellow).
--- @param output string
--- @return string
function M.colorizer(output)
  if not options.get().colorize_test_output == true or not output then
    return output
  end

  if string.find(output, "FAIL") then
    output = output:gsub("^", "[31m"):gsub("$", "[0m")
  elseif string.find(output, "PASS") then
    output = output:gsub("^", "[32m"):gsub("$", "[0m")
  elseif string.find(output, "SKIP") then
    output = output:gsub("^", "[33m"):gsub("$", "[0m")
  end
  return output
end

return M
