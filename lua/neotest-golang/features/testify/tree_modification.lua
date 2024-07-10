--- Opt-in functionality to support testify suites.

local lookup = require("neotest-golang.features.testify.lookup")

local M = {}

--- Modify the neotest tree, so that testify suites are properly described.
---
--- When testify tests are discovered, they are discovered with the Go receiver
--- as the Neotest namespace. This is incorrect, and to fix this, we need to do
--- a search-replace of the receiver with the suite name.
--- @param tree neotest.Tree The original neotest tree
--- @return neotest.Tree The modified tree.
function M.modify_neotest_tree(tree)
  local lookup_map = lookup.get()

  if not lookup_map then
    vim.notify(
      "No lookup found. Could not modify Neotest tree for testify suite support",
      vim.log.levels.WARN
    )
    return tree
  end

  local modified_tree = M.replace_receiver_with_suite(tree:root(), lookup_map)
  local tree_with_merged_namespaces =
    M.merge_duplicate_namespaces(modified_tree)
  return tree_with_merged_namespaces
end

--- Replace receiver methods with their corresponding test suites in the tree.
--- @param tree neotest.Tree The tree to modify
--- @param file_lookup table The lookup table containing receiver-to-suite mappings
--- @return neotest.Tree The modified tree with receivers replaced by suites
function M.replace_receiver_with_suite(tree, file_lookup)
  if not file_lookup then
    return tree
  end

  -- Create a global replacements table and suite names set
  local global_replacements = {}
  local suite_names = {}
  for _, file_data in pairs(file_lookup) do
    if file_data.suites then
      for receiver, suite in pairs(file_data.suites) do
        global_replacements[receiver] = suite
        suite_names[suite] = true
      end
    end
  end

  if vim.tbl_isempty(global_replacements) then
    -- no replacements found
    return tree
  end

  M.recursive_update(tree, global_replacements, suite_names)
  M.fix_relationships(tree)

  return tree
end

--- Merge duplicate namespaces in the tree.
---
--- Without this merging, the namespace will reappear once for each testify test.
--- @param tree neotest.Tree The tree to merge duplicate namespaces in
--- @return neotest.Tree The tree with merged duplicate namespaces
function M.merge_duplicate_namespaces(tree)
  if not tree._children or #tree._children == 0 then
    return tree
  end

  local namespaces = {}
  local new_children = {}

  for _, child in ipairs(tree._children) do
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

  tree._children = new_children
  return tree
end

-- Utility functions

--- Perform the neotest.Position id replacement.
---
--- Namespaces and tests are delimited by "::" and we need to replace the receiver
--- with the suite name here.
--- @param str string The neotest.Position id
--- @param receiver string The receiver name
--- @param suite string The suite name
--- @return string The modified neotest.Position id string
function M.replace_receiver_in_pos_id(str, receiver, suite)
  local modified = str:gsub("::" .. receiver .. "::", "::" .. suite .. "::")
  modified = modified:gsub("::" .. receiver .. "$", "::" .. suite)
  return modified
end

--- Update a single neotest.Tree node with the given replacements.
--- @param n neotest.Tree The node to update
--- @param replacements table<string, string> A table of old-to-new replacements
--- @param suite_names table<string, boolean> A set of known suite names
function M.update_node(n, replacements, suite_names)
  for receiver, suite in pairs(replacements) do
    if n._data.name == receiver then
      n._data.name = suite
      n._data.type = "namespace"
    elseif suite_names[n._data.name] then
      n._data.type = "namespace"
    end
    n._data.id = M.replace_receiver_in_pos_id(n._data.id, receiver, suite)
  end
end

--- Update the nodes table with the given replacements.
--- @param nodes table<string, neotest.Tree> The table of nodes to update
--- @param replacements table<string, string> A table of old-to-new replacements
--- @return table<string, neotest.Tree> The updated nodes table
function M.update_nodes_table(nodes, replacements)
  local new_nodes = {}
  for key, value in pairs(nodes) do
    local new_key = key
    for old, new in pairs(replacements) do
      new_key = M.replace_receiver_in_pos_id(new_key, old, new)
    end
    new_nodes[new_key] = value
  end
  return new_nodes
end

--- Recursively update a tree/node and its children with the given replacements.
--- @param n neotest.Tree The tree to update recursively
--- @param replacements table<string, string> A table of old-to-new replacements
--- @param suite_names table<string, boolean> A set of known suite names
function M.recursive_update(n, replacements, suite_names)
  M.update_node(n, replacements, suite_names)
  n._nodes = M.update_nodes_table(n._nodes, replacements)
  for _, child in ipairs(n:children()) do
    M.recursive_update(child, replacements, suite_names)
  end
end

--- Ensure parent-child relationships are correct after updating all nodes.
--- @param n neotest.Tree The node to fix relationships for
function M.fix_relationships(n)
  for _, child in ipairs(n:children()) do
    child._parent = n
    M.fix_relationships(child)
  end
end

return M
