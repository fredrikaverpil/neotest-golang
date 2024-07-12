--- Helpers around filepaths.

local plenary_scan = require("plenary.scandir")

local M = {}

--- Find a file upwards in the directory tree and return its path, if found.
--- @param filename string
--- @param start_path string
--- @return string | nil
function M.file_upwards(filename, start_path)
  local scan = require("plenary.scandir")
  local found_filepath = nil
  while start_path ~= vim.fn.expand("$HOME") do
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

-- Get all *_test.go files in a directory recursively.
function M.go_test_filepaths(folderpath)
  local files = plenary_scan.scan_dir(folderpath, {
    search_pattern = "_test%.go$",
    depth = math.huge,
    add_dirs = false,
  })
  return files
end

return M
