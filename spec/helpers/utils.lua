--- Common test utilities

local M = {}

--- Normalize Windows paths for cross-platform testing (forward slash → backslash)
--- @param path string
--- @return string
function M.normalize_path(path)
  if vim.fn.has("win32") == 1 then
    local normalized_path, _ = path:gsub("/", "\\")
    return normalized_path
  end
  return path
end

--- Normalize Windows paths to Unix style (backslash → forward slash)
--- @param path string
--- @return string
function M.to_unix_path(path)
  local unix_path, _ = path:gsub("\\", "/")
  return unix_path
end

return M
