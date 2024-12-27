--- Helpers around filepaths.

local scandir = require("plenary.scandir")

local logger = require("neotest-golang.logging")

local M = {}

M.os_path_sep = package.config:sub(1, 1) -- "/" on Unix, "\" on Windows

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
    logger.debug("Searching for " .. filename .. " in " .. start_dir)

    local try_path = start_dir .. M.os_path_sep .. filename
    if vim.fn.filereadable(try_path) == 1 then
      logger.info("Found " .. filename .. " at " .. try_path)
      return try_path
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
