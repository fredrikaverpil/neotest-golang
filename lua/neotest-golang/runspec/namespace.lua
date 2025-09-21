--- Helpers to build the command and context around running all tests in a namespace.

local extra_args = require("neotest-golang.extra_args")
local lib = require("neotest-golang.lib")
local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")

local M = {}

--- Build runspec for all tests in a namespace
--- @param pos neotest.Position Position data for the namespace
--- @param tree neotest.Tree Neotest tree containing test structure
--- @return neotest.RunSpec|nil Runspec for executing tests in the namespace
function M.build(pos, tree)
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

  local test_name = lib.convert.pos_id_to_go_test_name(pos.id)
  if not test_name then
    logger.error("Could not determine test name for position id: " .. pos.id)
    return nil
  end
  test_name = lib.convert.to_gotest_regex_pattern(test_name)

  local test_cmd, json_filepath =
    lib.cmd.test_command_in_package_with_regexp(pos_path_folderpath, test_name)

  local env = extra_args.get().env or options.get().env
  if type(env) == "function" then
    env = env()
  end

  local stream, stop_filestream =
    lib.stream.new(tree, golist_data, json_filepath)

  --- @type RunspecContext
  local context = {
    pos_id = pos.id,
    golist_data = golist_data,
    errors = errors,
    test_output_json_filepath = json_filepath,
    stop_filestream = stop_filestream,
  }

  --- @type neotest.RunSpec
  local run_spec = {
    command = test_cmd,
    cwd = pos_path_folderpath,
    context = context,
    env = env,
    stream = stream,
  }

  logger.debug({ "RunSpec:", run_spec })
  return run_spec
end

return M
