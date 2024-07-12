--- Helpers to build the command and context around running all tests of
--- a Go package.

local cmd = require("neotest-golang.cmd")
local find = require("neotest-golang.find")

local M = {}

--- Build runspec for a directory.
---
--- Strategy:
--- 1. Find the go.mod file from pos.path.
--- 2. Run `go test` from the directory containing the go.mod file.
--- 3. Use the relative path from the go.mod file to pos.path as the test pattern.
--- @param pos neotest.Position
--- @return neotest.RunSpec | nil
function M.build(pos)
  local go_mod_filepath = find.file_upwards("go.mod", pos.path)
  if go_mod_filepath == nil then
    -- if no go.mod file was found up the directory tree, until reaching $CWD,
    -- then we cannot determine the Go project root.
    return M.fail_fast(pos)
  end

  local go_mod_folderpath = vim.fn.fnamemodify(go_mod_filepath, ":h")
  local golist_data = cmd.golist_data(go_mod_folderpath)

  -- find the go package that corresponds to the go_mod_folderpath
  local package_name = "./..."
  for _, golist_item in ipairs(golist_data) do
    if pos.path == golist_item.Dir then
      if golist_item.Name == "main" then
        -- do nothing, keep ./...
      else
        package_name = golist_item.ImportPath
        break
      end
    end
  end

  local test_cmd, json_filepath = cmd.test_command_in_package(package_name)

  --- @type RunspecContext
  local context = {
    pos_id = pos.id,
    pos_type = "dir",
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
  local msg = "The selected folder must contain a go.mod file "
    .. "or be a subdirectory of a Go package."
  vim.notify(msg, vim.log.levels.ERROR)

  --- @type RunspecContext
  local context = {
    pos_id = pos.id,
    pos_type = "dir",
    golist_data = {}, -- no golist output
    parse_test_results = false,
  }

  --- @type neotest.RunSpec
  local run_spec = {
    command = { "echo", msg },
    context = context,
  }
  return run_spec
end

return M
