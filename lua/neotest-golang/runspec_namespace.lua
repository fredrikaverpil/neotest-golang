--- Helpers to build the command and context around running a single test.

local convert = require("neotest-golang.convert")
local cmd = require("neotest-golang.cmd")

local M = {}

--- Build runspec for a single test
--- @param pos neotest.Position
--- @return neotest.RunSpec | neotest.RunSpec[] | nil
function M.build(pos)
  --- @type string
  local test_folder_absolute_path = string.match(pos.path, "(.+)/")
  local golist_data = cmd.golist_data(test_folder_absolute_path)

  --- @type string
  local test_name = convert.to_gotest_test_name(pos.id)
  test_name = convert.to_gotest_regex_pattern(test_name)

  local test_cmd, json_filepath = cmd.test_command_in_package_with_regexp(
    test_folder_absolute_path,
    test_name
  )

  vim.notify(vim.inspect(test_cmd))

  --- @type RunspecContext
  local context = {
    pos_id = pos.id,
    pos_type = "namespace",
    golist_data = golist_data,
    parse_test_results = true,
    test_output_json_filepath = json_filepath,
  }

  --- @type neotest.RunSpec
  local run_spec = {
    command = test_cmd,
    cwd = test_folder_absolute_path,
    context = context,
  }

  return run_spec
end

return M
