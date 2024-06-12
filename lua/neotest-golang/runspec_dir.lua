local _ = require("neotest") -- fix LSP errors

local options = require("neotest-golang.options")

local M = {}

--- Build runspec for a directory.
---@param pos neotest.Position
---@return neotest.RunSpec | nil
function M.build(pos)
  -- Strategy:
  -- 1. Find the go.mod file from pos.path.
  -- 2. Run `go test` from the directory containing the go.mod file.
  -- 3. Use the relative path from the go.mod file to pos.path as the test pattern.
  local go_mod_filepath = M.find_file_upwards("go.mod", pos.path)
  if go_mod_filepath == nil then
    vim.notify(
      "The selected folder is not a Go project, attempting different strategy.",
      vim.log.levels.WARN
    )
    return nil -- Deletgates away from the dir strategy
  end

  local go_mod_folderpath = vim.fn.fnamemodify(go_mod_filepath, ":h")
  local cwd = go_mod_folderpath

  -- calculate the relative path to pos.path from cwd
  local relative_path = M.remove_base_path(cwd, pos.path)
  local test_pattern = "./" .. relative_path .. "/..."

  return M.build_dir_test_runspec(pos, cwd, test_pattern)
end

function M.find_file_upwards(filename, start_path)
  local scan = require("plenary.scandir")
  local cwd = vim.fn.getcwd() -- get the current working directory
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
  return found_filepath
end

function M.remove_base_path(base_path, target_path)
  if string.find(target_path, base_path, 1, true) == 1 then
    return string.sub(target_path, string.len(base_path) + 2)
  end

  return target_path
end

--- Build runspec for a directory of tests
---@param pos neotest.Position
---@param cwd string
---@param test_pattern string
---@return neotest.RunSpec
function M.build_dir_test_runspec(pos, cwd, test_pattern)
  local gotest = {
    "go",
    "test",
    "-json",
  }

  ---@type table
  local go_test_args = {
    test_pattern,
  }

  local combined_args =
    vim.list_extend(vim.deepcopy(options._go_test_args), go_test_args)
  local gotest_command = vim.list_extend(vim.deepcopy(gotest), combined_args)

  ---@type neotest.RunSpec
  local run_spec = {
    command = gotest_command,
    cwd = cwd,
    context = {
      id = pos.id,
      test_filepath = pos.path,
      test_type = "dir",
    },
  }

  return run_spec
end

return M
