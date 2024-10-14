--- Helpers to build the command and context around running all tests in a namespace.

local logger = require("neotest-golang.logging")
local lib = require("neotest-golang.lib")

local M = {}

--- Build runspec for a single test
--- @param pos neotest.Position
--- @return neotest.RunSpec | neotest.RunSpec[] | nil
function M.build(pos)
  local test_folder_absolute_path =
    string.match(pos.path, "(.+)" .. lib.find.os_path_sep)

  local golist_data, golist_error =
    lib.cmd.golist_data(test_folder_absolute_path)

  local errors = nil
  if golist_error ~= nil then
    if errors == nil then
      errors = {}
    end
    table.insert(errors, golist_error)
  end

  local test_name = lib.convert.to_gotest_test_name(pos.id)
  local test_name_regexp = lib.convert.to_gotest_regex_pattern(test_name)

  -- find the go package that corresponds to the pos.path
  local package_name = "./..."
  local pos_path_filename = vim.fn.fnamemodify(pos.path, ":t")
  local pos_path_foldername = vim.fn.fnamemodify(pos.path, ":h")
  for _, golist_item in ipairs(golist_data) do
    if golist_item.TestGoFiles ~= nil then
      if
        pos_path_foldername == golist_item.Dir
        and vim.tbl_contains(golist_item.TestGoFiles, pos_path_filename)
      then
        package_name = golist_item.ImportPath
        break
      end
    end
  end

  local cmd_data = {
    package_name = package_name,
    position = pos,
    regexp = test_name_regexp,
  }
  local test_cmd, test_output_filepath = lib.cmd.test_command(cmd_data)

  --- @type RunspecContext
  local context = {
    pos_id = pos.id,
    golist_data = golist_data,
    errors = errors,
    test_output_filepath = test_output_filepath,
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
