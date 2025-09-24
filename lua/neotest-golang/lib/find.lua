--- File system search operations for Go test discovery.

local scandir = require("plenary.scandir")

local logger = require("neotest-golang.lib.logging")
local path = require("neotest-golang.lib.path")

local M = {}

--- Find a file upwards in the directory tree and return its path, if found.
--- @param filename string Name of file to search for
--- @param start_path string Starting directory or file path to search from
--- @return string|nil Full path to found file or nil if not found
function M.file_upwards(filename, start_path)
  -- Ensure start_path is a directory
  local start_dir = vim.fn.isdirectory(start_path) == 1 and start_path
    or path.get_directory(start_path)
  local home_dir = vim.fn.expand("$HOME")

  while start_dir ~= home_dir do
    logger.debug("Searching for " .. filename .. " in " .. start_dir)

    local try_path = start_dir .. path.os_path_sep .. filename
    if vim.fn.filereadable(try_path) == 1 then
      logger.info("Found " .. filename .. " at " .. try_path)
      return try_path
    end

    -- Go up one directory
    start_dir = path.get_directory(start_dir)
  end

  return nil
end

--- Get all *_test.go files in a directory recursively.
--- @param folderpath string Directory path to search in
--- @return string[] Array of full paths to test files
function M.go_test_filepaths(folderpath)
  local files = scandir.scan_dir(
    folderpath,
    { search_pattern = "_test%.go$", add_dirs = false }
  )
  return files
end

return M
