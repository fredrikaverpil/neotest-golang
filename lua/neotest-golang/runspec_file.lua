--- Helpers to build the command and context around running all tests of a file.

local cmd = require("neotest-golang.cmd")
local runspec_dir = require("neotest-golang.runspec_dir")

local M = {}

--- Build runspec for a directory.
--- @param pos neotest.Position
--- @param tree neotest.Tree
--- @return neotest.RunSpec | neotest.RunSpec[] | nil
function M.build(pos, tree)
  if vim.tbl_isempty(tree:children()) then
    M.fail_fast(pos)
  end

  local go_mod_filepath = runspec_dir.find_file_upwards("go.mod", pos.path)
  if go_mod_filepath == nil then
    -- if no go.mod file was found up the directory tree, until reaching $CWD,
    -- then we cannot determine the Go project root.
    return M.fail_fast(pos)
  end

  local go_mod_folderpath = vim.fn.fnamemodify(go_mod_filepath, ":h")
  local golist_data = cmd.golist_data(go_mod_folderpath)

  -- find the go module that corresponds to the go_mod_folderpath
  local module_name = "./..." -- if no go module, run all tests at the $CWD

  local test_names_regexp =
    M.find_tests_in_file(pos, golist_data, go_mod_folderpath, module_name)
  local test_cmd, json_filepath =
    cmd.test_command_for_file(module_name, test_names_regexp)

  --- @type RunspecContext
  local context = {
    pos_id = pos.id,
    pos_type = "file",
    golist_data = golist_data,
    parse_test_results = true,
    test_output_json_filepath = json_filepath,
  }

  --- @type neotest.RunSpec
  local run_spec = {
    command = test_cmd,
    cwd = go_mod_folderpath,
    context = context,
  }

  return run_spec
end

function M.fail_fast(pos)
  --- @type RunspecContext
  local context = {
    pos_id = pos.id,
    pos_type = "file",
    golist_data = {}, -- no golist output
    parse_test_results = true,
    dummy_test = true,
  }

  --- Runspec designed for files that contain no tests.
  --- @type neotest.RunSpec
  local run_spec = {
    command = { "echo", "No tests found in file" },
    context = context,
  }
  return run_spec
end

function M.find_tests_in_file(pos, golist_data, go_mod_folderpath, module_name)
  local pos_path_filename = vim.fn.fnamemodify(pos.path, ":t")

  for _, golist_item in ipairs(golist_data) do
    if golist_item.TestGoFiles ~= nil then
      if vim.tbl_contains(golist_item.TestGoFiles, pos_path_filename) then
        module_name = golist_item.ImportPath
        break
      end
    end
  end

  -- FIXME: this grabs all test files from the package. We only want the one in the file.
  local test_names = cmd.gotest_list_data(go_mod_folderpath, module_name)
  local test_names_regexp = "^(" .. table.concat(test_names, "|") .. ")$"

  return test_names_regexp
end

return M
