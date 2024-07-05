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
    return M.fail_fast(pos)
  end

  local go_mod_filepath = runspec_dir.find_file_upwards("go.mod", pos.path)
  if go_mod_filepath == nil then
    -- if no go.mod file was found up the directory tree, until reaching $CWD,
    -- then we cannot determine the Go project root.
    return M.fail_fast(pos)
  end

  local go_mod_folderpath = vim.fn.fnamemodify(go_mod_filepath, ":h")
  local golist_data = cmd.golist_data(go_mod_folderpath)

  -- find the go package that corresponds to the pos.path
  local package_name = "./..."
  local pos_path_filename = vim.fn.fnamemodify(pos.path, ":t")
  for _, golist_item in ipairs(golist_data) do
    if golist_item.TestGoFiles ~= nil then
      if vim.tbl_contains(golist_item.TestGoFiles, pos_path_filename) then
        package_name = golist_item.ImportPath
        break
      end
    end
  end

  -- find all top-level tests in pos.path
  local test_cmd = nil
  local json_filepath = nil
  local regexp = cmd.get_regexp(pos.path)
  if regexp ~= nil then
    test_cmd, json_filepath =
      cmd.test_command_in_package_with_regexp(package_name, regexp)
  else
    -- fallback: run all tests in the package
    test_cmd, json_filepath = cmd.test_command_in_package(package_name)
    -- NOTE: could also fall back to running on a per-test basis by using a bare return
  end

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
    parse_test_results = false,
  }

  --- Runspec designed for files that contain no tests.
  --- @type neotest.RunSpec
  local run_spec = {
    command = { "echo", "No tests found in file" },
    context = context,
  }
  return run_spec
end

return M
