--- Functions to modify the Neotest tree, for testify suite support.

local lib = require("neotest-golang.lib")
local logger = require("neotest-golang.lib.logging")
local lookup = require("neotest-golang.features.testify.lookup")

local M = {}

---@type table<string, any> | nil
local lookup_table = lookup.get_lookup()
---@type string[]
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
--- @return neotest.Tree The modified tree
function M.modify_neotest_tree(file_path, tree)
  if vim.tbl_isempty(lookup_table) then
    ---@type string[]
    ignore_filepaths_during_init = lib.find.go_test_filepaths(vim.fn.getcwd())
    ---@type table<string, any> | nil
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

  -- Collect all replacements from all files for cross-file suite support
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

--- Create proper testify hierarchy where receiver methods become children of suite functions
--- @param tree neotest.Tree The original tree
--- @param replacements table<string, string> Receiver type to suite function mappings
--- @param global_lookup_table table The global lookup table for cross-file method discovery
--- @return neotest.Tree The tree with proper testify hierarchy
function M.create_testify_hierarchy(tree, replacements, global_lookup_table)
  -- Build method_positions map from lookup table data (no re-parsing!)
  ---@type table<string, table[]>
  local method_positions = {}

  if global_lookup_table then
    for file_path, file_data in pairs(global_lookup_table) do
      if file_data.methods then
        -- Aggregate method information from all files
        for method_name, instances in pairs(file_data.methods) do
          if not method_positions[method_name] then
            method_positions[method_name] = {}
          end
          -- Add all instances of this method from this file
          for _, instance in ipairs(instances) do
            table.insert(method_positions[method_name], instance)
          end
        end
      end
    end
  end

  -- Collect all positions
  ---@type neotest.Position[]
  local positions = {}
  for i, pos in tree:iter() do
    table.insert(positions, pos)
  end

  -- Separate positions by type
  ---@type neotest.Position | nil
  local file_pos = nil
  ---@type table<string, neotest.Position> -- TestExampleTestSuite, TestExampleTestSuite2
  local suite_functions = {}
  ---@type neotest.Position[] -- TestExample, TestExample2 (from receivers)
  local receiver_methods = {}
  ---@type neotest.Position[] -- TestTrivial
  local regular_tests = {}
  ---@type neotest.Position[] -- subtest positions
  local subtests = {}

  for _, pos in ipairs(positions) do
    if pos.type == "file" then
      file_pos = pos
    elseif pos.type == "test" then
      -- Check if this is a suite function
      ---@type boolean
      local is_suite_function = false
      for receiver_type, suite_function in pairs(replacements) do
        if pos.name == suite_function then
          suite_functions[suite_function] = pos
          is_suite_function = true
          break
        end
      end

      if not is_suite_function then
        -- Check if this is a subtest
        if pos.id:match('::%b""') then
          table.insert(subtests, pos)
        elseif method_positions[pos.name] then
          -- This is a receiver method
          table.insert(receiver_methods, pos)
        else
          -- This is a regular test
          table.insert(regular_tests, pos)
        end
      end
    end
  end

  -- Build new tree structure
  local Tree = require("neotest.types.tree")
  ---@type neotest.Tree[]
  local root_children = {}

  -- Helper function to create tree nodes consistently
  ---@param pos neotest.Position
  ---@param children neotest.Tree[] | nil
  ---@return neotest.Tree
  local function create_tree_node(pos, children)
    children = children or {}
    return Tree:new(pos, children, function(data)
      return data.id
    end)
  end

  -- Add suite functions as namespaces with their methods as children
  for suite_function, suite_pos in pairs(suite_functions) do
    -- Convert suite function to namespace
    suite_pos.type = "namespace"

    -- Find the receiver type for this suite function
    ---@type string | nil
    local receiver_type = nil
    for recv_type, suite_func in pairs(replacements) do
      if suite_func == suite_function then
        receiver_type = recv_type
        break
      end
    end

    -- Find methods that belong to this receiver type (from current file AND other files)
    ---@type neotest.Tree[]
    local suite_children = {}

    -- First, process methods from current file
    for _, method_pos in ipairs(receiver_methods) do
      -- Find which receiver this method belongs to by matching position ranges
      ---@type boolean
      local belongs_to_receiver = M.find_method_receiver(
        method_pos,
        method_positions[method_pos.name],
        receiver_type
      )

      if belongs_to_receiver then
        -- Update the method's ID to include the namespace
        ---@type string
        local pattern = "::" .. method_pos.name .. "$"
        ---@type string
        local replacement = "::" .. suite_function .. "::" .. method_pos.name
        method_pos.id = method_pos.id:gsub(pattern, replacement)

        -- Add subtests as children of this method
        ---@type neotest.Tree[]
        local method_children = {}
        for _, subtest_pos in ipairs(subtests) do
          if subtest_pos.id:find("::" .. method_pos.name .. "::", 1, true) then
            subtest_pos.id = subtest_pos.id:gsub(
              "::" .. method_pos.name .. "::",
              "::" .. suite_function .. "::" .. method_pos.name .. "::"
            )
            table.insert(method_children, create_tree_node(subtest_pos, {}))
          end
        end

        table.insert(
          suite_children,
          create_tree_node(method_pos, method_children)
        )
      end
    end

    -- Add cross-file methods for this receiver type
    for method_name, instances in pairs(method_positions) do
      for _, instance in ipairs(instances) do
        if
          instance.receiver == receiver_type
          and instance.source_file ~= tree:data().path
        then
          ---@type neotest.Position
          local synthetic_pos = {
            type = "test",
            name = method_name,
            id = tree:data().path
              .. "::"
              .. suite_function
              .. "::"
              .. method_name,
            path = tree:data().path,
            range = nil,
          }

          table.insert(suite_children, create_tree_node(synthetic_pos, {}))
        end
      end
    end

    table.insert(root_children, create_tree_node(suite_pos, suite_children))
  end

  -- Add regular tests with their subtests
  for _, test_pos in ipairs(regular_tests) do
    ---@type neotest.Tree[]
    local test_children = {}

    -- Find subtests that belong to this regular test
    for _, subtest_pos in ipairs(subtests) do
      -- Check if this subtest belongs to this test (not already assigned to a suite method)
      if subtest_pos.id:find("::" .. test_pos.name .. "::", 1, true) then
        -- Make sure it's not a suite subtest (those were already processed above)
        local already_processed = false
        for _, suite_pos in pairs(suite_functions) do
          if subtest_pos.id:find("::" .. suite_pos.name .. "::", 1, true) then
            already_processed = true
            break
          end
        end

        if not already_processed then
          table.insert(test_children, create_tree_node(subtest_pos, {}))
        end
      end
    end

    table.insert(root_children, create_tree_node(test_pos, test_children))
  end

  -- Create new tree with file as root and updated children
  return create_tree_node(file_pos, root_children)
end

--- Find which receiver a method position belongs to by matching line ranges
--- @param method_pos neotest.Position The neotest position for the method
--- @param method_instances table[] | nil List of instances with receiver and definition info
--- @param target_receiver string | nil The receiver type we're looking for
--- @return boolean True if the method belongs to the target receiver
function M.find_method_receiver(method_pos, method_instances, target_receiver)
  if not method_instances or #method_instances == 0 then
    return false
  end

  -- If there's only one instance, check if it matches
  if #method_instances == 1 then
    return method_instances[1].receiver == target_receiver
  end

  -- For multiple instances, match by line range using node information
  if method_pos.range then
    ---@type number
    local method_start_line = method_pos.range[1]
    ---@type number
    local method_end_line = method_pos.range[3]

    ---@type table | nil
    local best_match = nil
    ---@type number
    local best_distance = math.huge

    for _, instance in ipairs(method_instances) do
      if instance.definition and instance.definition.node then
        ---@type TSNode
        local node = instance.definition.node
        ---@type number, number, number, number
        local start_row, _, end_row, _ = node:range()

        if start_row <= method_end_line and end_row >= method_start_line then
          ---@type number
          local distance = math.abs(start_row - method_start_line)

          if
            instance.receiver == target_receiver and distance < best_distance
          then
            best_match = instance
            best_distance = distance
          end
        end
      end
    end

    return best_match ~= nil
  end

  -- Fallback: if no range info, don't assign to avoid duplicates
  return false
end

return M
