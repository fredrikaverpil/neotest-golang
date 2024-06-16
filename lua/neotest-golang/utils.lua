local M = {}

--- Check if a table is empty.
--- @param t table
--- @return boolean
function M.table_is_empty(t)
  return next(t) == nil
end

return M
