local parsers = require("nvim-treesitter.parsers")

local M = {}

--- Run a TreeSitter query on a file and return the matches.
--- @param filepath string The path to the file to query
--- @param query_string string The TreeSitter query string
--- @return table<string, table> A table of matches, where each key is a capture name and the value is a table of nodes
function M.run_query_on_file(filepath, query_string)
  local bufnr = vim.api.nvim_create_buf(false, true)
  local content = vim.fn.readfile(filepath)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

  vim.api.nvim_set_option_value("filetype", "go", { buf = bufnr })

  if not parsers.has_parser("go") then
    error("Go parser is not available. Please ensure it's installed.")
  end

  local parser = parsers.get_parser(bufnr, "go")
  local tree = parser:parse()[1]
  local root = tree:root()

  ---@type vim.treesitter.Query
  local query = vim.treesitter.query.parse("go", query_string)

  local matches = {}

  for pattern, match, metadata in
    query:iter_matches(root, bufnr, 0, -1, { all = true })
  do
    for id, nodes in pairs(match) do
      local name = query.captures[id]
      for _, node in ipairs(nodes) do
        M.add_match(matches, name, node, bufnr, metadata[id])
      end
    end
  end

  vim.api.nvim_buf_delete(bufnr, { force = true })

  return matches
end

--- Add a match to the matches table
--- @param matches table<string, table> The table of matches to add to
--- @param name string The name of the capture
--- @param node TSNode The TreeSitter node
--- @param bufnr integer The buffer number
--- @param metadata? table Optional metadata for the node
function M.add_match(matches, name, node, bufnr, metadata)
  if not matches[name] then
    matches[name] = {}
  end
  table.insert(
    matches[name],
    {
      name = name,
      node = node,
      text = M.get_node_text(node, bufnr, { metadata = metadata }),
    }
  )
end

--- Get the text of a TreeSitter node.
--- @param node TSNode The TreeSitter node
--- @param bufnr integer|string The buffer number or content
--- @param opts? table Optional parameters (e.g., metadata for a specific capture)
--- @return string The text of the node
function M.get_node_text(node, bufnr, opts)
  local text = vim.treesitter.get_node_text(node, bufnr, opts) -- NOTE: uses vim.treesitter
  if type(text) == "table" then
    return table.concat(text, "\n")
  end
  return text
end

return M
