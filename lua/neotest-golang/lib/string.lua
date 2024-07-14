local M = {}

---Check if a string starts with a given prefix.
---@param str string
---@param prefix string
function M.starts_with(str, prefix)
  if str == nil or prefix == nil then
    return false
  end
  return str:sub(1, #prefix) == prefix
end

return M
