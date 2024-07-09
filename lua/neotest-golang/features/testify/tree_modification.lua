--- Opt-in functionality to support testify suites.

local lookup = require("neotest-golang.features.testify.lookup")

local M = {}

---@param file_path string
---@param tree neotest.Tree
function M.modify_neotest_tree(file_path, tree)
  local lookup_map = lookup.get()

  if not lookup_map then
    return tree
  end

  local modified_tree = M.replace_receiver_with_suite(tree:root(), lookup_map)
  local tree_with_merged_namespaces =
    M.merge_duplicate_namespaces(modified_tree)
  return tree_with_merged_namespaces
end

function M.replace_receiver_with_suite(node, file_lookup)
  if not file_lookup then
    return node
  end

  local function replace_in_string(str, old, new)
    return str
      :gsub("::" .. old .. "::", "::" .. new .. "::")
      :gsub("::" .. old .. "$", "::" .. new)
  end

  local function update_node(n, replacements, suite_names)
    for old, new in pairs(replacements) do
      if n._data.name == old then
        n._data.name = new
        n._data.type = "namespace"
      elseif suite_names[n._data.name] then
        n._data.type = "namespace"
      end
      n._data.id = replace_in_string(n._data.id, old, new)
    end
  end

  local function update_nodes_table(nodes, replacements)
    local new_nodes = {}
    for key, value in pairs(nodes) do
      local new_key = key
      for old, new in pairs(replacements) do
        new_key = replace_in_string(new_key, old, new)
      end
      new_nodes[new_key] = value
    end
    return new_nodes
  end

  local function recursive_update(n, replacements, suite_names)
    update_node(n, replacements, suite_names)
    n._nodes = update_nodes_table(n._nodes, replacements)
    for _, child in ipairs(n:children()) do
      recursive_update(child, replacements, suite_names)
    end
  end

  -- Create a global replacements table and suite names set
  local global_replacements = {}
  local suite_names = {}
  for file_path, file_data in pairs(file_lookup) do
    if file_data.suites then
      for receiver, suite in pairs(file_data.suites) do
        global_replacements[receiver] = suite
        suite_names[suite] = true
      end
    else
      -- no suites found for file
    end
  end

  if vim.tbl_isempty(global_replacements) then
    -- no replacements found
    return node
  end

  recursive_update(node, global_replacements, suite_names)

  -- After updating all nodes, ensure parent-child relationships are correct
  local function fix_relationships(n)
    for _, child in ipairs(n:children()) do
      child._parent = n
      fix_relationships(child)
    end
  end

  fix_relationships(node)

  return node
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

return M
