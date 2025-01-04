--- Helpers to build the command and context around running all tests of
--- a Go package.

local logger = require("neotest-golang.logging")
local lib = require("neotest-golang.lib")

local M = {}

--- Given the pos.path, find the corresponding Go package import path.
--- Example:
---   pos.path = "~/projects/projectx/internal/core"
---   import_path = "github.com/foo/projectx/internal/core"
---
---Two strategies are going to be used:
--- 1. Perfect match.
--- 2. Sub-package match.
---@param pos neotest.Position
---@param golist_data table
local function find_go_package_import_path(pos, golist_data)
  ---@type string|nil
  local package_import_path = nil

  -- 1. Perfect match: main package.
  for _, golist_item in ipairs(golist_data) do
    if
      (
        golist_item.Module.GoMod
          == pos.path .. lib.find.os_path_sep .. "go.mod"
        and golist_item.Name == "main"
      ) or (pos.path == golist_item.Dir and golist_item.Name == "main")
    then
      package_import_path = golist_item.ImportPath .. "/..."
      return "./..."
    end
  end

  -- 2. Perfect match: the selected directory corresponds to a package.
  for _, golist_item in ipairs(golist_data) do
    if pos.path == golist_item.Dir then
      package_import_path = golist_item.ImportPath .. "/..."
      return package_import_path
    end
  end

  -- 3. Sub-package match: the selected directory does not correspond
  -- to a package, but might correspond to one or more sub-packages.
  local subpackage_import_paths = {}
  for _, golist_item in ipairs(golist_data) do
    if string.find(golist_item.Dir, pos.path, 1, true) then
      -- a sub-package was detected to exist under the selected dir.
      table.insert(subpackage_import_paths, 1, golist_item.ImportPath)
    end
  end
  if subpackage_import_paths then
    -- let's figure out the sub-package with the shortest name.
    local shortest = subpackage_import_paths[1]
    local length = string.len(subpackage_import_paths[1])
    for _, candidate in ipairs(subpackage_import_paths) do
      if string.len(candidate) < length then
        shortest = candidate
        length = string.len(candidate)
      end
    end

    package_import_path = vim.fn.fnamemodify(shortest, ":h") .. "/..."
    return package_import_path
  end

  return nil
end

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
  local golist_data, golist_error = lib.cmd.golist_data(pos.path)

  local errors = nil
  if golist_error ~= nil then
    if errors == nil then
      errors = {}
    end
    table.insert(errors, golist_error)
  end

  local package_import_path = find_go_package_import_path(pos, golist_data)
  if not package_import_path then
    logger.error("Could not find a package for the selected dir: " .. pos.path)
  end

  local test_cmd, json_filepath =
    lib.cmd.test_command_in_package(package_import_path)

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
    cwd = pos.path,
    context = context,
  }

  logger.debug({ "RunSpec:", run_spec })
  return run_spec
end

return M
