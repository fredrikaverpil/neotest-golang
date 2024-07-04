--- Helpers to build the command and context around running all tests of
--- a Go module.

local cmd = require("neotest-golang.cmd")

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
  local go_mod_filepath = M.find_file_upwards("go.mod", pos.path)
  if go_mod_filepath == nil then
    -- if no go.mod file was found up the directory tree, until reaching $CWD,
    -- then we cannot determine the Go project root.
    return M.fail_fast(pos)
  end

  local go_mod_folderpath = vim.fn.fnamemodify(go_mod_filepath, ":h")
  local golist_data = cmd.golist_data(go_mod_folderpath)

  -- find the go module that corresponds to the go_mod_folderpath
  local module_name = "./..." -- if no go module, run all tests at the $CWD
  for _, golist_item in ipairs(golist_data) do
    if pos.path == golist_item.Dir then
      module_name = golist_item.ImportPath
      break
    end
  end

  local test_cmd, json_filepath = cmd.test_command_for_dir(module_name)

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
    .. "or be a subdirectory of a Go module."
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

--- Find a file upwards in the directory tree and return its path, if found.
--- @param filename string
--- @param start_path string
--- @return string | nil
function M.find_file_upwards(filename, start_path)
  local scan = require("plenary.scandir")
  local cwd = vim.fn.getcwd()
  local found_filepath = nil
  while start_path ~= cwd do
    local files = scan.scan_dir(
      start_path,
      { search_pattern = filename, hidden = true, depth = 1 }
    )
    if #files > 0 then
      found_filepath = files[1]
      break
    end
    start_path = vim.fn.fnamemodify(start_path, ":h") -- go up one directory
  end

  if found_filepath == nil then
    -- check if filename exists in the current directory
    local files = scan.scan_dir(
      start_path,
      { search_pattern = filename, hidden = true, depth = 1 }
    )
    if #files > 0 then
      found_filepath = files[1]
    end
  end

  return found_filepath
end

function M.remove_base_path(base_path, target_path)
  if string.find(target_path, base_path, 1, true) == 1 then
    return string.sub(target_path, string.len(base_path) + 2)
  end

  return target_path
end

return M
