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

--- Load multiple queries and concatenate them
--- @param query_paths table List of relative paths to .scm files
--- @return string The concatenated query content
function M.load_queries(query_paths)
  local queries = {}
  for _, path in ipairs(query_paths) do
    table.insert(queries, M.load_query(path))
  end
  return table.concat(queries, "\n")
end

return M
