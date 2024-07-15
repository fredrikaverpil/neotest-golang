--- Functions to modify the Neotest tree, for testify suite support.

local logger = require("neotest-golang.logging")
local lib = require("neotest-golang.lib")
local lookup = require("neotest-golang.features.testify.lookup")

local M = {}

local lookup_table = lookup.get_lookup()
local ignore_filepaths_during_init = {}

--- Modify the neotest tree, so that testify suites can be executed
--- as Neotest namespaces.
---
--- When testify tests are discovered, they are discovered with the Go receiver
--- type as the Neotest namespace. However, to produce a valid test path,
--- this receiver type must be replaced with the testify suite name in the
--- Neotest tree.
--- @param file_path string The path to the test file
--- @param tree neotest.Tree The original neotest tree
--- @return neotest.Tree The modified tree.
function M.modify_neotest_tree(file_path, tree)
  if vim.tbl_isempty(lookup_table) then
    ignore_filepaths_during_init = lib.find.go_test_filepaths(vim.fn.getcwd())
    lookup_table = lookup.initialize_lookup(ignore_filepaths_during_init)
  end

  if vim.tbl_contains(ignore_filepaths_during_init, file_path) then
    -- some optimization;
    -- ignore the first call, as it is handled by the initialization above.
    for i, path in ipairs(ignore_filepaths_during_init) do
      if path == file_path then
        table.remove(ignore_filepaths_during_init, i)
        break
      end
    end
  else
    -- after initialization, always update the lookup for the given filepath.
    lookup_table = lookup.create_lookup(file_path)
  end

  if not lookup_table then
    logger.warn(
      "No lookup found. Could not modify Neotest tree for testify suite support"
    )
    return tree
  end

  local modified_tree = {}
  modified_tree = M.replace_receiver_with_suite(tree:root(), lookup_table)
  modified_tree = M.merge_duplicate_namespaces(modified_tree)

  return modified_tree
end

--- Replace receiver methods with their corresponding test suites in the tree.
--- @param tree neotest.Tree The tree to modify
--- @param lookup_table table The lookup table containing receiver-to-suite mappings
--- @return neotest.Tree The modified tree with receivers replaced by suites
function M.replace_receiver_with_suite(tree, lookup_table)
  if not lookup_table then
    return tree
  end

  -- TODO: To make this more robust, it would be a good idea to only perform replacements
  -- within the relevant Go package. Right now, this implementation is naive and will
  -- not check for package boundaries. Replacement are done "globally", replacing 'a' with
  -- 'b' everywhere, across all test files.
  local replacements = {}
  local suite_functions = {}
  for _, file_data in pairs(lookup_table) do
    if file_data.replacements then
      for receiver_type, suite_function in pairs(file_data.replacements) do
        replacements[receiver_type] = suite_function
        suite_functions[suite_function] = true
      end
    end
  end

  if vim.tbl_isempty(replacements) then
    -- no replacements found
    return tree
  end

  M.recursive_update(tree, replacements, suite_functions)
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

--- Perform the neotest.Position id replacement.
---
--- Namespaces and tests are delimited by "::" and we need to replace the receiver
--- with the suite name here.
--- @param str string The neotest.Position id
--- @param receiver_type string The receiver type
--- @param suite_function string The suite function name
--- @return string The modified neotest.Position id string
function M.replace_receiver_in_pos_id(str, receiver_type, suite_function)
  local modified =
    str:gsub("::" .. receiver_type .. "::", "::" .. suite_function .. "::")
  modified = modified:gsub("::" .. receiver_type .. "$", "::" .. suite_function)
  return modified
end

--- Update a single neotest.Tree node with the given replacements.
--- @param n neotest.Tree The node to update
--- @param replacements table<string, string> A table of old-to-new replacements
--- @param suite_functions table<string, boolean> A set of known suite functions
function M.update_node(n, replacements, suite_functions)
  -- TODO: To make this more robust, it would be a good idea to only perform replacements
  -- within the relevant Go package. Right now, this implementation is naive and will
  -- not check for package boundaries. Replacement are done "globally", replacing 'a' with
  -- 'b' everywhere, across all test files.
  for receiver, suite in pairs(replacements) do
    if n._data.name == receiver then
      n._data.name = suite
      n._data.type = "namespace"
    elseif suite_functions[n._data.name] then
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
--- @param suite_functions table<string, boolean> A set of known suite functions
function M.recursive_update(n, replacements, suite_functions)
  M.update_node(n, replacements, suite_functions)
  n._nodes = M.update_nodes_table(n._nodes, replacements)
  for _, child in ipairs(n:children()) do
    M.recursive_update(child, replacements, suite_functions)
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
