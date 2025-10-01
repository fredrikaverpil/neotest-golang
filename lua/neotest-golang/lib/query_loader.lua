--- Helper functions for loading tree-sitter queries from .scm files

local M = {}

--- Load a query from a .scm file
--- @param query_path string Relative path to the .scm file from the lua/neotest-golang directory
--- @return string The query content
function M.load_query(query_path)
  local full_path = debug.getinfo(1, "S").source:sub(2) -- Get current file path
  local base_dir = vim.fn.fnamemodify(full_path, ":h:h") -- Go up to neotest-golang directory
  local absolute_path = vim.fn.resolve(base_dir .. "/" .. query_path)

  local file = io.open(absolute_path, "r")
  if not file then
    error("Could not open query file: " .. absolute_path)
  end

  local content = file:read("*all")
  file:close()

  return content
end

--- Clear the query cache (useful for testing)
--- @return nil
function M.clear_cache()
  query_cache = {}
end

return M
