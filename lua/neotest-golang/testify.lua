local M = {}

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

function M.find_parent_function(node)
  while node do
    if node:type() == "function_declaration" then
      return node
    end
    node = node:parent()
  end
  return nil
end

function M.get_function_name(func_node, content)
  for child in func_node:iter_children() do
    if child:type() == "identifier" then
      return vim.treesitter.get_node_text(child, content)
    end
  end
  return "anonymous"
end

function M.run_query_on_file(filepath, query_string)
  local file = io.open(filepath, "r")
  if not file then
    error("Could not open file: " .. filepath)
  end
  local content = file:read("*all")
  file:close()

  local lang = "go"
  local parser = vim.treesitter.get_string_parser(content, lang)
  local tree = parser:parse()[1]
  local root = tree:root()

  local query = vim.treesitter.query.parse(lang, query_string)
  local matches = {}

  for id, node, metadata in query:iter_captures(root, content, 0, -1) do
    local name = query.captures[id]
    local text = vim.treesitter.get_node_text(node, content)

    local func_node = M.find_parent_function(node)
    if func_node then
      local func_name = M.get_function_name(func_node, content)
      if not matches[func_name] then
        matches[func_name] = {}
      end
      table.insert(
        matches[func_name],
        { name = name, node = node, text = text }
      )
    else
      if not matches["global"] then
        matches["global"] = {}
      end
      table.insert(matches["global"], { name = name, node = node, text = text })
    end
  end

  return matches
end

return M
