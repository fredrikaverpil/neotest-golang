--- Helpers around filepaths.

local scandir = require("plenary.scandir")

local convert = require("neotest-golang.lib.convert")

local M = {}

--- Find a file upwards in the directory tree and return its path, if found.
--- @param filename string
--- @param start_path string
--- @return string | nil
function M.file_upwards(filename, start_path)
  local found_filepath = nil
  while start_path ~= vim.fn.expand("$HOME") do
    local files = scandir.scan_dir(start_path, {
      search_pattern = convert.to_lua_pattern(filename),
      depth = 1,
      add_dirs = false,
    })
    if #files > 0 then
      found_filepath = files[1]
      return found_filepath
    end
  end

  if found_filepath == nil then
    -- go up one directory and try again
    start_path = vim.fn.fnamemodify(start_path, ":h")
    return M.file_upwards(filename, start_path)
  end
end

-- Get all *_test.go files in a directory recursively.
function M.go_test_filepaths(folderpath)
  local files = scandir.scan_dir(
    folderpath,
    { search_pattern = "_test%.go$", add_dirs = false }
  )
  return files
end

return M
