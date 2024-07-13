--- Helpers around filepaths.

local scandir = require("plenary.scandir")

local convert = require("neotest-golang.lib.convert")

local M = {}

--- Find a file upwards in the directory tree and return its path, if found.
--- @param filename string
--- @param start_path string
--- @return string | nil
function M.file_upwards(filename, start_path)
  -- Ensure start_path is a directory
  local start_dir = vim.fn.isdirectory(start_path) == 1 and start_path
    or vim.fn.fnamemodify(start_path, ":h")
  local home_dir = vim.fn.expand("$HOME")

  while start_dir ~= home_dir do
    local files = scandir.scan_dir(start_dir, {
      search_pattern = convert.to_lua_pattern(filename),
      depth = 1,
      add_dirs = false,
    })
    if #files > 0 then
      return files[1]
    end

    -- Go up one directory
    start_dir = vim.fn.fnamemodify(start_dir, ":h")
  end

  return nil
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
