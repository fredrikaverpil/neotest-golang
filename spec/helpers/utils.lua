--- Common test utilities

local M = {}

--- Normalize Windows paths to Unix style (backslash → forward slash)
--- @param path string
--- @return string
function M.to_unix_path(path)
  local unix_path, _ = path:gsub("\\", "/")
  return unix_path
end

return M
