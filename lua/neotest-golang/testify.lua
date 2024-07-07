local ts = require("nvim-treesitter.ts_utils")
local parsers = require("nvim-treesitter.parsers")

local M = {}

local testify_query = [[
  ; query
  (function_declaration ; [38, 0] - [40, 1]
    name: (identifier) @testify.function_name ; [38, 5] - [38, 14]
    ;parameters: (parameter_list ; [38, 14] - [38, 28]
    ;  (parameter_declaration ; [38, 15] - [38, 27]
    ;    name: (identifier) ; [38, 15] - [38, 16]
    ;    type: (pointer_type ; [38, 17] - [38, 27]
    ;      (qualified_type ; [38, 18] - [38, 27]
    ;        package: (package_identifier) ; [38, 18] - [38, 25]
    ;        name: (type_identifier))))) ; [38, 26] - [38, 27]
    body: (block ; [38, 29] - [40, 1]
      (expression_statement ; [39, 1] - [39, 34]
        (call_expression ; [39, 1] - [39, 34]
          function: (selector_expression ; [39, 1] - [39, 10]
            operand: (identifier) @testify.module ; [39, 1] - [39, 6]
            field: (field_identifier) @testify.run ) @testify.call ; [39, 7] - [39, 10]
          arguments: (argument_list ; [39, 10] - [39, 34]
            (identifier) @testify.t ; [39, 11] - [39, 12]
            (call_expression ; [39, 14] - [39, 33]
              function: (identifier) ; [39, 14] - [39, 17]
              arguments: (argument_list ; [39, 17] - [39, 33]
                (type_identifier) @testify.receiver ))))))) @testify.definition
  ]]

--- A lookup map between receiver method name and suite name.
--- Example:

local lookup_map = {}

function M.get()
  return lookup_map
end

function M.add(file_name, suite_name, receiver_name)
  if not lookup_map[file_name] then
    lookup_map[file_name] = {}
  end
  table.insert(
    lookup_map[file_name],
    { suite = suite_name, receiver = receiver_name }
  )
end

function M.clear()
  lookup_map = {}
end

function M.merge_duplicate_namespaces(node)
  if not node._children or #node._children == 0 then
    return node
  end

  local namespaces = {}
  local new_children = {}

  for _, child in ipairs(node._children) do
    if child._data.type == "namespace" then
      local existing = namespaces[child._data.name]
      if existing then
        -- Merge children of duplicate namespace
        for _, grandchild in ipairs(child._children) do
          table.insert(existing._children, grandchild)
          grandchild._parent = existing
        end
      else
        namespaces[child._data.name] = child
        table.insert(new_children, child)
      end
    else
      table.insert(new_children, child)
    end
  end

  -- Recursively process children
  for _, child in ipairs(new_children) do
    M.merge_duplicate_namespaces(child)
  end

  node._children = new_children
  return node
end

function M.get_node_text(node, bufnr)
  local text = vim.treesitter.get_node_text(node, bufnr) -- NOTE: uses vim.treesitter
  if type(text) == "table" then
    return table.concat(text, "\n")
  end
  return text
end

function M.run_query_on_file(filepath, query_string)
  -- Create a new buffer and set its content
  local bufnr = vim.api.nvim_create_buf(false, true)
  local content = vim.fn.readfile(filepath)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)

  -- Set the buffer's filetype to Go
  vim.api.nvim_set_option_value("filetype", "go", { buf = bufnr })

  -- Ensure the Go parser is available
  if not parsers.has_parser("go") then
    error("Go parser is not available. Please ensure it's installed.")
  end

  -- Parse the buffer
  local parser = parsers.get_parser(bufnr, "go")
  local tree = parser:parse()[1]
  local root = tree:root()

  -- Create a query
  local query = vim.treesitter.query.parse("go", query_string)

  local matches = {}

  for pattern, match, metadata in query:iter_matches(root, bufnr, 0, -1) do
    local function_name = nil
    local current_function = {}

    for id, node in pairs(match) do
      local name = query.captures[id]
      local text = M.get_node_text(node, bufnr)

      if name == "testify.function_name" then
        function_name = text
      end

      table.insert(current_function, { name = name, node = node, text = text })
    end

    if function_name then
      matches[function_name] = current_function
    end
  end

  -- Clean up: delete the temporary buffer
  vim.api.nvim_buf_delete(bufnr, { force = true })

  return matches
end

return M
