--- Helpers to build the command and context around running all tests in a namespace.

local extra_args = require("neotest-golang.extra_args")
local lib = require("neotest-golang.lib")
local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")

local M = {}

--- Build runspec for a single test
--- @param pos neotest.Position
--- @return neotest.RunSpec | neotest.RunSpec[] | nil
function M.build(pos)
  local pos_path_folderpath =
    string.match(pos.path, "(.+)" .. lib.find.os_path_sep)

  local golist_data, golist_error = lib.cmd.golist_data(pos_path_folderpath)

  local errors = nil
  if golist_error ~= nil then
    if errors == nil then
      errors = {}
    end
    table.insert(errors, golist_error)
  end

  local test_name = lib.convert.to_gotest_test_name(pos.id)
  test_name = lib.convert.to_gotest_regex_pattern(test_name)

  local test_cmd, json_filepath =
    lib.cmd.test_command_in_package_with_regexp(pos_path_folderpath, test_name)

  local env = extra_args.get().env or options.get().env
  if type(env) == "function" then
    env = env()
  end

  --- @type RunspecContext
  local context = {
    pos_id = pos.id,
    golist_data = golist_data,
    errors = errors,
    test_output_json_filepath = json_filepath,
  }

  --- @type neotest.RunSpec
  local run_spec = {
    command = test_cmd,
    cwd = pos_path_folderpath,
    context = context,
    env = env,
  }

  logger.debug({ "RunSpec:", run_spec })
  return run_spec
end

return M
