--- Functions to modify the Neotest tree, for testify suite support.

local lib = require("neotest-golang.lib")
local logger = require("neotest-golang.lib.logging")
local lookup = require("neotest-golang.features.testify.lookup")

local M = {}

---@type table<string, any> | nil
local lookup_table = lookup.get_lookup()
---@type string[]
local ignore_filepaths_during_init = {}

--- Modify the neotest tree, so that testify suite tests can be executed.
---
--- Testify test IDs are renamed from ::MethodName to ::SuiteName/MethodName
--- to match go test -run syntax and enable proper "nearest test" behavior.
--- @param file_path string The path to the test file
--- @param tree neotest.Tree The original neotest tree
--- @return neotest.Tree The modified tree
function M.modify_neotest_tree(file_path, tree)
  if not lookup_table or vim.tbl_isempty(lookup_table) then
    ---@type string[]
    ignore_filepaths_during_init = lib.find.go_test_filepaths(vim.fn.getcwd())
    ---@type table<string, any> | nil
    lookup_table = lookup.initialize_lookup(ignore_filepaths_during_init)
  end

  if vim.tbl_contains(ignore_filepaths_during_init, file_path) then
    -- optimization: ignore the first call, as it is handled by the initialization above.
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
      "No lookup found. Could not modify Neotest tree for testify suite support",
      true
    )
    return tree
  end

  -- Get file-specific mappings
  ---@type table | nil
  local file_data = lookup_table[file_path]
  if not file_data or not file_data.replacements then
    return tree
  end

  -- Collect all replacements from all files (package-qualified receiver keys)
  ---@type table<string, string>
  local global_replacements = {}
  for _, data in pairs(lookup_table) do
    if data.replacements then
      for receiver, suite in pairs(data.replacements) do
        global_replacements[receiver] = suite
      end
    end
  end

  ---@type neotest.Tree
  local modified_tree =
    M.create_testify_hierarchy(tree, global_replacements, lookup_table)

  return modified_tree
end

--- Checks if range a is subrange of range b
--- @param a integer[] range a represented as 4 integers: start_row, start_col, end_row, end_col
--- @param b integer[] range b represented as 4 integers: start_row, start_col, end_row, end_col
--- @return boolean Is a subrange of b
local function is_sub_range(a, b)
    local a_start_row, a_start_col, a_end_row, a_end_col = a[1], a[2], a[3], a[4]
    local b_start_row, b_start_col, b_end_row, b_end_col = b[1], b[2], b[3], b[4]
    return (
      (a_start_row > b_start_row or
        (a_start_row == b_start_row and a_start_col >= b_start_col)) and
      (a_end_row < b_end_row or
        (a_end_row == b_end_row and a_end_col <= b_end_col))
    )
end

--- Merges range a and range b into the smallest range that contains both
--- @param a integer[] range a represented as 4 integers: start_row, start_col, end_row, end_col
--- @param b integer[] range b represented as 4 integers: start_row, start_col, end_row, end_col
--- @return integer[] merged range
local function merge_ranges(a, b)
    local a_start_row, a_start_col, a_end_row, a_end_col = a[1], a[2], a[3], a[4]
    local b_start_row, b_start_col, b_end_row, b_end_col = b[1], b[2], b[3], b[4]
    local start_row, start_col, end_row, end_col = 0, 0, 0, 0
    if a_start_row < b_start_row or (a_start_row == b_start_row and a_start_col < b_start_col) then
        start_row = a_start_row
        start_col = a_start_col
    else
        start_row = b_start_row
        start_col = b_start_col
    end
    if a_end_row > b_end_row or (a_end_row == b_end_row and a_end_col > b_end_col) then
        end_row = a_end_row
        end_col = a_end_col
    else
        end_row = b_end_row
        end_col = b_end_col
    end
    return { start_row, start_col, end_row, end_col }
end

--- Create flat testify hierarchy where receiver methods are renamed to include suite prefix
--- with slash separator (e.g., ::SuiteName/MethodName). Suite functions are removed from tree.
--- @param tree neotest.Tree The original tree
--- @param replacements table<string, string> Receiver type to suite function mappings
--- @param global_lookup_table table The global lookup table
--- @return neotest.Tree The tree with flat testify structure
function M.create_testify_hierarchy(tree, replacements, global_lookup_table)
  -- Build method_positions map from lookup table data
  ---@type table<string, table[]>
  local method_positions = {}

  if global_lookup_table then
    -- Search for method information from current file only (no cross-file)
    local file_data = global_lookup_table[tree:data().path]
    if file_data then
      for method_name, instances in pairs(file_data.methods) do
        if not method_positions[method_name] then
          method_positions[method_name] = {}
        end
        for _, instance in ipairs(instances) do
          table.insert(method_positions[method_name], instance)
        end
      end
    end
  end

  -- Root of the neotest tree should be a file type
  -- This will be needed when constructing the new tree
  if tree:data().type ~= "file" then
    logger.error("No file position found in tree")
    return tree
  end

  ---@type neotest.Position
  local file_pos = tree:data()

  -- Build new tree structure
  ---@type neotest.Tree[]
  local root_children = {}
  ---@type table<string, neotest.Tree>
  local suite_constructors = {}
  ---@type neotest.Tree[]
  local suite_methods = {}
  -- First pass: identify test suites, suite methods and normal tests
  -- Leave suite methods and normal tests as-is in new tree structure
  for _, top_level_test in pairs(tree:children()) do
      local pos = top_level_test:data()
      local is_suite_function = false
      for _, suite_function in pairs(replacements) do
        if pos.name == suite_function then
          is_suite_function = true
          break
        end
      end
      if is_suite_function then
        table.insert(root_children, top_level_test)
        suite_constructors[pos.name] = top_level_test
      else
          local is_testify_method = method_positions[pos.name]
          if is_testify_method then
            table.insert(suite_methods, top_level_test)
          else
            table.insert(root_children, top_level_test)
          end
      end
  end

  -- Second pass: process suite methods:
  --   1) update their (and their sub-test) properties so they will run correctly
  --   2) attach them as children to their parent suites
  --   3) if parent suite is not in the same file, rename them by adding a prefix
  for _, method_node in pairs(suite_methods) do
      ---@type neotest.Position
      local pos = method_node:data()
      ---@type neotest.Tree | nil
      local parent = nil
      ---@type string | nil
      local parent_name = nil
      for _, method in pairs(method_positions[pos.name]) do
        if is_sub_range(pos.range, { method.definition.node:range(false) }) then
            parent_name = replacements[method.receiver]
            parent = suite_constructors[parent_name]
            break
        end
      end
      if not parent_name then
          logger.error("No suitable parent test found for testify method")
          break
      end
      if parent then
          local parent_data = parent:data()
          local parent_total_range = parent_data.total_range or parent_data.range
          parent_data.total_range = merge_ranges(parent_total_range, pos.range)
      end
      -- Add suite name as a prefix in the id of the current test and its sub-tests.
      -- This id is later converted to the relevant "go test" command to execute the test.
      local pattern = "::" .. pos.name
      local replacement = "::" .. parent_name .. "::" .. pos.name
      for _, test in method_node:iter() do
        test.id = test.id:gsub(pattern, replacement)
      end
      if parent ~= nil then
        -- Suite is defined in the same file. Attach current method as child.
        ---@diagnostic disable-next-line: invisible
        parent:add_child(pos.name, method_node)
      else
        -- Suite is not defined in the same file.
        -- Add prefix to current method name to make it clear and attach it to the root of the tree.
        pos.name = parent_name .. "/" .. pos.name
        table.insert(root_children, method_node)
      end
  end

  -- Sort children by start of range to ensure tree iteration order matches file line order
  -- This is critical for Neotest's "nearest test" algorithm to work correctly
  table.sort(root_children, function(a, b)
    local a_pos = a:data()
    local b_pos = b:data()
    local a_range = a_pos.total_range or a_pos.range
    local b_range = b_pos.total_range or b_pos.range
    -- Use range start line for comparison
    if a_range and b_range then
      return a_range[1] < b_range[1]
    end
    return false
  end)

  -- Create new tree with file as root and updated children
  local Tree = require("neotest.types.tree")
  ---@diagnostic disable-next-line: invisible
  return Tree:new(file_pos, root_children, function(data)
    return data.id
  end)
end

return M
