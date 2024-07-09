--- Helpers around filepaths.

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
-- FIXME: do not use `find`, as this puts unnecessary dependency here?
-- Might want to use plenary instead.
function M.go_test_filepaths(folderpath)
  local files = {}
  local function scan_dir(dir)
    local p = io.popen('find "' .. dir .. '" -type f -name "*_test.go"')
    for file in p:lines() do
      table.insert(files, file)
    end
  end
  scan_dir(folderpath)
  return files
end

return M
