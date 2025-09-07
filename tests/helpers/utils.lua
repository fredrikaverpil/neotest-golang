--- Common test utilities

local M = {}

--- Normalize Windows paths for cross-platform testing (forward slash → backslash)
--- @param path string
--- @return string
function M.normalize_path(path)
  if vim.fn.has("win32") == 1 then
    return path:gsub("/", "\\")
  end
  return path
end

--- Normalize Windows paths to Unix style (backslash → forward slash)
--- @param path string
--- @return string
function M.to_unix_path(path)
  return path:gsub("\\", "/")
end

return M