--- Helpers around filepaths.

local scandir = require("plenary.scandir")

local logger = require("neotest-golang.lib.logging")

local M = {}

M.os_path_sep = package.config:sub(1, 1) -- "/" on Unix, "\" on Windows

--- Get directory part of a path (Windows-safe replacement for fnamemodify(path, ":h")).
--- Preserves original path separators to avoid Windows path breakage.
--- @param path string File or directory path
--- @return string Directory part of the path
function M.get_directory(path)
  if not path or path == "" then
    return "."
  end

  -- Handle edge cases
  if path == "/" or path == "\\" then
    return path
  end

  -- Find the last separator (either / or \)
  local last_sep_pos = 0
  for i = #path, 1, -1 do
    local char = path:sub(i, i)
    if char == "/" or char == "\\" then
      last_sep_pos = i
      break
    end
  end

  if last_sep_pos == 0 then
    -- No separator found, it's just a filename
    return "."
  elseif last_sep_pos == 1 then
    -- Root directory
    return path:sub(1, 1)
  else
    -- Return everything before the last separator
    return path:sub(1, last_sep_pos - 1)
  end
end

--- Get filename part of a path (Windows-safe replacement for fnamemodify(path, ":t")).
--- Preserves original path separators to avoid Windows path breakage.
--- @param path string File or directory path
--- @return string Filename part of the path
function M.get_filename(path)
  if not path or path == "" then
    return ""
  end

  -- Find the last separator (either / or \)
  local last_sep_pos = 0
  for i = #path, 1, -1 do
    local char = path:sub(i, i)
    if char == "/" or char == "\\" then
      last_sep_pos = i
      break
    end
  end

  if last_sep_pos == 0 then
    -- No separator found, return the whole string
    return path
  else
    -- Return everything after the last separator
    return path:sub(last_sep_pos + 1)
  end
end

--- Find a file upwards in the directory tree and return its path, if found.
--- @param filename string Name of file to search for
--- @param start_path string Starting directory or file path to search from
--- @return string|nil Full path to found file or nil if not found
function M.file_upwards(filename, start_path)
  -- Ensure start_path is a directory
  local start_dir = vim.fn.isdirectory(start_path) == 1 and start_path
    or M.get_directory(start_path)
  local home_dir = vim.fn.expand("$HOME")

  while start_dir ~= home_dir do
    logger.debug("Searching for " .. filename .. " in " .. start_dir)

    local try_path = start_dir .. M.os_path_sep .. filename
    if vim.fn.filereadable(try_path) == 1 then
      logger.info("Found " .. filename .. " at " .. try_path)
      return try_path
    end

    -- Go up one directory
    start_dir = M.get_directory(start_dir)
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
