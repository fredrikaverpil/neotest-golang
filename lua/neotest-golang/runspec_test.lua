--- Helpers to build the command and context around running a single test.

local async = require("neotest.async")

local convert = require("neotest-golang.convert")
local options = require("neotest-golang.options")
local json = require("neotest-golang.json")
local cmd = require("neotest-golang.cmd")
local dap = require("neotest-golang.dap")

local M = {}

--- Build runspec for a single test
--- @param pos neotest.Position
--- @param strategy string
--- @return neotest.RunSpec | neotest.RunSpec[] | nil
function M.build(pos, strategy)
  --- @type string
  local test_folder_absolute_path = string.match(pos.path, "(.+)/")
  local go_list_command = cmd.build_golist_cmd(test_folder_absolute_path)
  local golist_output = json.process_golist_output(go_list_command)

  --- @type string
  local test_name = convert.to_gotest_test_name(pos.id)
  test_name = convert.to_gotest_regex_pattern(test_name)

  local test_cmd, json_filepath = cmd.build_test_command_for_individual_test(
    test_folder_absolute_path,
    test_name
  )

  local runspec_strategy = nil
  if strategy == "dap" then
    if options.get().dap_go_enabled then
      runspec_strategy = dap.get_dap_config(test_name)
      dap.setup_debugging(test_folder_absolute_path)
    end
  end

  --- @type neotest.RunSpec
  local run_spec = {
    command = test_cmd,
    cwd = test_folder_absolute_path,
    context = {
      id = pos.id,
      test_filepath = pos.path,
      golist_output = golist_output,
      pos_type = "test",
    },
  }

  if json_filepath ~= nil then
    run_spec.context.jsonfile = json_filepath
  end

  if runspec_strategy ~= nil then
    run_spec.strategy = runspec_strategy
    run_spec.context.skip = true
  end

  return run_spec
end

return M
