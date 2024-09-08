--- Helpers to build the command and context around running all tests of
--- a Go package.

local logger = require("neotest-golang.logging")
local lib = require("neotest-golang.lib")

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
  local go_mod_filepath = lib.find.file_upwards("go.mod", pos.path)
  if go_mod_filepath == nil then
    logger.error(
      "The selected directory does not contain a go.mod file or is not part of a Go module."
    )
    return nil -- NOTE: logger.error will throw an error, but the LSP doesn't see it.
  end

  local go_mod_folderpath = vim.fn.fnamemodify(go_mod_filepath, ":h")
  local golist_data, golist_error = lib.cmd.golist_data(go_mod_folderpath)

  local errors = {}
  if golist_error ~= nil then
    table.insert(errors, golist_error)
  end

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

  local test_cmd, json_filepath = lib.cmd.test_command_in_package(package_name)

  --- @type RunspecContext
  local context = {
    pos_id = pos.id,
    golist_data = golist_data,
    errors = errors,
    parse_test_results = true,
    test_output_json_filepath = json_filepath,
  }

  --- @type neotest.RunSpec
  local run_spec = {
    command = test_cmd,
    cwd = go_mod_folderpath,
    context = context,
  }

  logger.debug({ "RunSpec:", run_spec })
  return run_spec
end

return M
