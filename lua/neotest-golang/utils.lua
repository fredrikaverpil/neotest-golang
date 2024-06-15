local M = {}

--- Check if a table is empty.
--- @param t table
--- @return boolean
function M.table_is_empty(t)
  return next(t) == nil
end

-- Find the common path of two folderpaths.
function M.find_common_path(path1, path2)
  local common = {}
  local path1_parts = vim.split(path1, "/")
  local path2_parts = vim.split(path2, "/")
  for i = #path1_parts, 1, -1 do
    if path1_parts[i] == path2_parts[#path2_parts] then
      table.insert(common, 1, path1_parts[i])
      table.remove(path2_parts)
    else
      break
    end
  end
  return table.concat(common, "/")
end

return M
