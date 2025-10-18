--- Tree Modification for Testify Suite Support
---
--- This module transforms Neotest's tree structure to properly represent testify test suites.
---
--- ## The Problem
--- Testify suites use Go receiver methods, but these appear as regular tests in the initial tree:
---   File
---   ├─ TestMySuite (the suite function with suite.Run())
---   ├─ TestMethod1 (actually a receiver method: func (s *MySuite) TestMethod1())
---   └─ TestMethod2 (actually a receiver method: func (s *MySuite) TestMethod2())
---
--- To run these tests, we need to execute: `go test -run TestMySuite/TestMethod1`
---
--- ## The Solution
--- Transform the tree so receiver methods become children of their suite:
---   File
---   └─ TestMySuite (namespace, converted from suite function)
---      ├─ TestMethod1 (ID: path::TestMySuite::TestMethod1)
---      └─ TestMethod2 (ID: path::TestMySuite::TestMethod2)
---
--- ## Special Cases Handled
---
--- 1. **Non-contiguous methods**: When test methods are spread throughout a file with
---    large gaps (>20 lines), only contiguous methods remain as children. Non-contiguous
---    methods become root-level siblings to prevent Neotest's "nearest test" algorithm
---    from getting stuck during depth-first traversal.
---
---    Example:
---      File
---      ├─ TestMySuite (namespace, lines 10-30)
---      │  ├─ TestMethod1 (line 15)
---      │  └─ TestMethod2 (line 25)
---      ├─ TestOtherSuite (namespace, lines 40-50)
---      │  └─ TestOtherMethod (line 45)
---      └─ TestMethod3 (line 100, ID: path::TestMySuite::TestMethod3) ← Root-level but still part of suite!
---
--- 2. **Cross-file suites**: When test methods exist in a different file than their
---    suite function, we create synthetic namespace entries.
---
--- 3. **Subtests**: Table-driven subtests are properly nested under their parent tests.

local lib = require("neotest-golang.lib")
local logger = require("neotest-golang.lib.logging")
local lookup = require("neotest-golang.features.testify.lookup")

local M = {}

---@type TestifyLookupTable | nil
local lookup_table = lookup.get_lookup()
---@type string[]
local ignore_filepaths_during_init = {}

--- Escape special Lua pattern characters in a string
--- @param str string The string to escape
--- @return string The escaped string safe to use in Lua patterns
local function escape_pattern(str)
  -- Escape all Lua pattern special characters: ^$()%.[]*+-?
  return str:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%1")
end

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
    ---@type TestifyLookupTable | nil
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
  ---@type TestifyFileData | nil
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

--- Process a suite function: convert it to namespace and attach its receiver methods as children
--- @param suite_function string The suite function name (e.g., "TestMySuite")
--- @param suite_pos neotest.Position The position of the suite function
--- @param replacements table<string, string> Map of receiver type to suite function name
--- @param receiver_methods neotest.Position[] All receiver methods found in the file
--- @param method_positions table<string, TestifyMethodInstance[]> Map of method names to their instances
--- @param subtests neotest.Position[] All subtests found in the file
--- @param tree neotest.Tree The original tree (for path information)
--- @param create_tree_node function Helper to create tree nodes
--- @param processed_methods table<string, boolean> Track which methods have been processed
--- @param M table Module table (for calling M.find_method_receiver)
--- @return neotest.Tree[] suite_children All children for this suite
local function process_suite(
  suite_function,
  suite_pos,
  replacements,
  receiver_methods,
  method_positions,
  subtests,
  tree,
  create_tree_node,
  processed_methods,
  M
)
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

  ---@type neotest.Tree[]
  local suite_children = {}

  -- Process methods from current file that belong to this receiver
  for _, method_pos in ipairs(receiver_methods) do
    local belongs_to_receiver = M.find_method_receiver(
      method_pos,
      method_positions[method_pos.name],
      receiver_type
    )

    if belongs_to_receiver then
      processed_methods[method_pos.name] = true

      -- Update the method's ID to include the namespace
      local pattern = "::" .. escape_pattern(method_pos.name) .. "$"
      local replacement_str = "::" .. suite_function .. "::" .. method_pos.name
      method_pos.id = method_pos.id:gsub(pattern, replacement_str)

      -- Attach subtests as children of this method
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

  -- Add cross-file methods for this receiver type (methods defined in other files)
  for method_name, instances in pairs(method_positions) do
    for _, instance in ipairs(instances) do
      if
        instance.receiver == receiver_type
        and instance.source_file ~= tree:data().path
      then
        -- Create synthetic position for cross-file method
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
          range = nil, -- No range because method is in another file
        }

        table.insert(suite_children, create_tree_node(synthetic_pos, {}))
      end
    end
  end

  return suite_children
end

--- Create proper testify hierarchy where receiver methods become children of suite functions
---
--- This is the main entry point that orchestrates the tree transformation.
--- @param tree neotest.Tree The original tree
--- @param replacements table<string, string> Receiver type to suite function mappings
--- @param global_lookup_table TestifyLookupTable The global lookup table for cross-file method discovery
--- @return neotest.Tree The tree with proper testify hierarchy
function M.create_testify_hierarchy(tree, replacements, global_lookup_table)
  -- Build method_positions map from lookup table data (no re-parsing!)
  ---@type table<string, TestifyMethodInstance[]>
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
  for _, pos in tree:iter() do
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

  -- Helper function to sort tree nodes by line number
  ---@param nodes neotest.Tree[] List of tree nodes to sort in place
  ---@return nil
  local function sort_by_line_number(nodes)
    table.sort(nodes, function(a, b)
      local a_range = a:data().range
      local b_range = b:data().range
      if not a_range then
        return false
      end
      if not b_range then
        return true
      end
      return a_range[1] < b_range[1]
    end)
  end

  -- Helper function to separate contiguous from non-contiguous children
  -- Returns two lists: contiguous children (for namespace) and non-contiguous (for root)
  ---@param children neotest.Tree[] List of child tree nodes
  ---@param namespace_pos neotest.Position The namespace position
  ---@return neotest.Tree[], neotest.Tree[] contiguous_children, non_contiguous_children
  local function separate_contiguous_children(children, namespace_pos)
    if #children == 0 then
      return {}, {}
    end

    -- Sort children by start line
    sort_by_line_number(children)

    ---@type neotest.Tree[]
    local contiguous = {}
    ---@type neotest.Tree[]
    local non_contiguous = {}
    ---@type number
    local MAX_GAP = 20

    -- First child is always contiguous
    local prev_end = nil
    for i, child_tree in ipairs(children) do
      local child_pos = child_tree:data()
      if child_pos.range then
        if prev_end == nil then
          -- First child with range
          table.insert(contiguous, child_tree)
          prev_end = child_pos.range[3]
        else
          local gap = child_pos.range[1] - prev_end
          if gap <= MAX_GAP then
            -- Contiguous with previous
            table.insert(contiguous, child_tree)
            prev_end = child_pos.range[3]
          else
            -- Non-contiguous, add to separate list
            table.insert(non_contiguous, child_tree)
          end
        end
      else
        -- No range (synthetic), add to contiguous
        table.insert(contiguous, child_tree)
      end
    end

    -- Adjust namespace range based on contiguous children
    if #contiguous > 0 then
      local first_range = contiguous[1]:data().range
      local last_range = contiguous[#contiguous]:data().range

      if first_range and last_range then
        if namespace_pos.range then
          namespace_pos.range[1] = first_range[1]
          namespace_pos.range[3] =
            math.max(last_range[3], namespace_pos.range[3])
        else
          namespace_pos.range = { first_range[1], 0, last_range[3], 0 }
        end
      end
    end

    return contiguous, non_contiguous
  end

  -- Track which methods have been processed to avoid duplicates
  ---@type table<string, boolean>
  local processed_methods = {}

  -- Step 1: Process suite functions that exist in this file
  -- These are the `func TestMySuite(t *testing.T)` functions that call suite.Run()
  for suite_function, suite_pos in pairs(suite_functions) do
    local suite_children = process_suite(
      suite_function,
      suite_pos,
      replacements,
      receiver_methods,
      method_positions,
      subtests,
      tree,
      create_tree_node,
      processed_methods,
      M
    )

    -- Separate contiguous from non-contiguous children to fix "nearest test" behavior
    local contiguous_children, non_contiguous_children =
      separate_contiguous_children(suite_children, suite_pos)

    -- Only add namespace if it has contiguous children (avoids empty namespaces)
    if #contiguous_children > 0 then
      table.insert(
        root_children,
        create_tree_node(suite_pos, contiguous_children)
      )
    end

    -- Add non-contiguous children to root but they keep their suite ID for execution
    for _, child in ipairs(non_contiguous_children) do
      table.insert(root_children, child)
    end
  end

  -- Step 2: Handle "orphaned" receiver methods
  -- These are receiver methods whose suite function is in a different file.
  -- Example: File A has `func (s *MySuite) TestFoo()` but the suite function
  --          `func TestMySuite(t *testing.T)` is in File B.
  -- We create a synthetic namespace for these methods.
  ---@type table<string, {suite_pos: neotest.Position, methods: neotest.Tree[]}>
  local synthetic_suites = {}

  for _, method_pos in ipairs(receiver_methods) do
    -- Skip methods already processed as part of a real suite
    if not processed_methods[method_pos.name] then
      -- Determine which receiver type this method belongs to by matching line ranges
      ---@type string | nil
      local method_receiver = nil
      ---@type TestifyMethodInstance[] | nil
      local method_instances = method_positions[method_pos.name]

      if method_instances and #method_instances > 0 then
        -- Try to match by line range using tree-sitter node information
        for _, instance in ipairs(method_instances) do
          if instance.source_file == tree:data().path then
            if
              instance.definition
              and instance.definition.node
              and method_pos.range
            then
              ---@type TSNode
              local node = instance.definition.node
              local start_row, _, end_row, _ = node:range()

              -- Check if ranges overlap
              if
                start_row <= method_pos.range[3]
                and end_row >= method_pos.range[1]
              then
                method_receiver = instance.receiver
                break
              end
            end
          end
        end

        -- Fallback: if only one instance exists, use that receiver
        if not method_receiver and #method_instances == 1 then
          method_receiver = method_instances[1].receiver
        end
      end

      if method_receiver then
        -- Look up the suite function name for this receiver
        local suite_function = replacements[method_receiver]

        if suite_function then
          -- Create synthetic suite namespace if it doesn't exist
          if not synthetic_suites[suite_function] then
            synthetic_suites[suite_function] = {
              suite_pos = {
                type = "namespace",
                name = suite_function,
                id = tree:data().path .. "::" .. suite_function,
                path = tree:data().path,
                range = nil, -- No range because suite function is in another file
              },
              methods = {},
            }
          end

          -- Update method ID to include suite namespace
          local pattern = "::" .. escape_pattern(method_pos.name) .. "$"
          local replacement_str = "::"
            .. suite_function
            .. "::"
            .. method_pos.name
          method_pos.id = method_pos.id:gsub(pattern, replacement_str)

          -- Attach subtests to this method
          ---@type neotest.Tree[]
          local method_children = {}
          for _, subtest_pos in ipairs(subtests) do
            if
              subtest_pos.id:find("::" .. method_pos.name .. "::", 1, true)
            then
              subtest_pos.id = subtest_pos.id:gsub(
                "::" .. method_pos.name .. "::",
                "::" .. suite_function .. "::" .. method_pos.name .. "::"
              )
              table.insert(method_children, create_tree_node(subtest_pos, {}))
            end
          end

          table.insert(
            synthetic_suites[suite_function].methods,
            create_tree_node(method_pos, method_children)
          )
        end
      end
    end
  end

  -- Add synthetic suites to tree
  for _, suite_data in pairs(synthetic_suites) do
    local contiguous_children, non_contiguous_children =
      separate_contiguous_children(suite_data.methods, suite_data.suite_pos)

    if #contiguous_children > 0 then
      table.insert(
        root_children,
        create_tree_node(suite_data.suite_pos, contiguous_children)
      )
    end

    for _, child in ipairs(non_contiguous_children) do
      table.insert(root_children, child)
    end
  end

  -- Step 3: Add regular tests (non-testify tests) with their subtests
  -- These are standard Go tests that don't use testify suites
  for _, test_pos in ipairs(regular_tests) do
    ---@type neotest.Tree[]
    local test_children = {}

    -- Attach subtests (table-driven tests) to their parent test
    for _, subtest_pos in ipairs(subtests) do
      -- Check if this subtest belongs to this test by ID pattern matching
      if subtest_pos.id:find("::" .. test_pos.name .. "::", 1, true) then
        -- Skip if it's already been processed as part of a suite method
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

  -- Sort all root children by line number to ensure correct behavior for Neotest's
  -- "nearest test" feature, which uses depth-first traversal
  sort_by_line_number(root_children)

  -- Return the final transformed tree
  return create_tree_node(file_pos, root_children)
end

--- Find which receiver a method position belongs to by matching line ranges
--- @param method_pos neotest.Position The neotest position for the method
--- @param method_instances TestifyMethodInstance[] | nil List of instances with receiver and definition info
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
