local options = require("neotest-golang.options")
local json = require("neotest-golang.json")

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

  -- if go_mod_filepath == nil then
  --   go_mod_filepath = M.find_file_upwards("go.work", pos.path)
  -- end

  -- if no go.mod file was found up the directory tree, until reaching $CWD,
  -- then we cannot determine the Go project root.
  if go_mod_filepath == nil then
    local msg = "The selected folder must contain a go.mod file "
      .. "or be a subdirectory of a Go module."
    vim.notify(msg, vim.log.levels.ERROR)
    local run_spec = {
      command = { "echo", msg },
      context = {
        id = pos.id,
        skip = true,
        pos_type = "dir",
      },
    }
    return run_spec
  end

  local go_mod_folderpath = vim.fn.fnamemodify(go_mod_filepath, ":h")
  local cwd = go_mod_folderpath

  -- call 'go list -json ./...' to get test file data
  local go_list_command = {
    "go",
    "list",
    "-json",
    "./...",
  }
  local go_list_command_result = vim.fn.system(
    "cd " .. go_mod_folderpath .. " && " .. table.concat(go_list_command, " ")
  )
  local golist_output = json.process_golist_output(go_list_command_result)

  -- find the go module that corresponds to the go_mod_folderpath
  local module_name = "./..." -- if no go module, run all tests at the $CWD
  for _, golist_item in ipairs(golist_output) do
    if pos.path == golist_item.Dir then
      module_name = golist_item.ImportPath
      break
    end
  end

  return M.build_dir_test_runspec(pos, cwd, golist_output, module_name)
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

--- Build runspec for a directory of tests
--- @param pos neotest.Position
--- @param cwd string
--- @param golist_output table
--- @param module_name string
--- @return neotest.RunSpec | neotest.RunSpec[] | nil
function M.build_dir_test_runspec(pos, cwd, golist_output, module_name)
  local gotest = {
    "go",
    "test",
    "-json",
  }

  --- @type table
  local required_go_test_args = {
    module_name,
  }

  local combined_args = vim.list_extend(
    vim.deepcopy(options.get().go_test_args),
    required_go_test_args
  )
  local gotest_command = vim.list_extend(vim.deepcopy(gotest), combined_args)

  --- @type neotest.RunSpec
  local run_spec = {
    command = gotest_command,
    cwd = cwd,
    context = {
      id = pos.id,
      test_filepath = pos.path,
      golist_output = golist_output,
      pos_type = "dir",
    },
  }

  return run_spec
end

return M
