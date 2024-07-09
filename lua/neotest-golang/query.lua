local parsers = require("nvim-treesitter.parsers")

local M = {}

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

  local query = vim.treesitter.query.parse("go", query_string)

  local matches = {}

  local function add_match(name, node)
    if not matches[name] then
      matches[name] = {}
    end
    table.insert(
      matches[name],
      { name = name, node = node, text = M.get_node_text(node, bufnr) }
    )
  end

  for pattern, match, metadata in query:iter_matches(root, bufnr, 0, -1) do
    for id, node in pairs(match) do
      local name = query.captures[id]
      add_match(name, node)
    end
  end

  vim.api.nvim_buf_delete(bufnr, { force = true })

  return matches
end

function M.get_node_text(node, bufnr)
  local text = vim.treesitter.get_node_text(node, bufnr) -- NOTE: uses vim.treesitter
  if type(text) == "table" then
    return table.concat(text, "\n")
  end
  return text
end

return M
