--- Helpers to build the command and context around running all tests in a namespace.

local lib = require("neotest-golang.lib")

local M = {}

--- Build runspec for a single test
--- @param pos neotest.Position
--- @return neotest.RunSpec | neotest.RunSpec[] | nil
function M.build(pos)
  --- @type string
  local test_folder_absolute_path =
    string.match(pos.path, "(.+)" .. lib.find.os_path_sep)
  local golist_data, golist_error =
    lib.cmd.golist_data(test_folder_absolute_path)

  --- @type string
  local test_name = lib.convert.to_gotest_test_name(pos.id)
  test_name = lib.convert.to_gotest_regex_pattern(test_name)

  local test_cmd, json_filepath = lib.cmd.test_command_in_package_with_regexp(
    test_folder_absolute_path,
    test_name
  )

  --- @type RunspecContext
  local context = {
    pos_id = pos.id,
    golist_data = golist_data,
    golist_error = golist_error,
    parse_test_results = true,
    test_output_json_filepath = json_filepath,
  }

  --- @type neotest.RunSpec
  local run_spec = {
    command = test_cmd,
    cwd = test_folder_absolute_path,
    context = context,
  }

  logger.debug({ "RunSpec:", run_spec })
  return run_spec
end

return M
