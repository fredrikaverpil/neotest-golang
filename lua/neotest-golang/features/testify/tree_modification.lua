--- Functions to modify the Neotest tree, for testify suite support.

local lib = require("neotest-golang.lib")
local logger = require("neotest-golang.lib.logging")
local lookup = require("neotest-golang.features.testify.lookup")

local M = {}

---@type table<string, any> | nil
local lookup_table = lookup.get_lookup()
---@type string[]
local ignore_filepaths_during_init = {}

--- Modify the neotest tree, so that testify suite tests can be executed
--- with proper IDs in a flat structure (no namespace nodes).
---
--- Testify test IDs are renamed from ::MethodName to ::SuiteName/MethodName
--- to match go test -run syntax and enable proper "nearest test" behavior.
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
    for file_path, file_data in pairs(global_lookup_table) do
      if file_data.methods then
        -- Aggregate method information from current file only (no cross-file)
        if file_path == tree:data().path then
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
  ---@type table<string, neotest.Position>
  local suite_functions = {} -- Will be removed from tree
  ---@type neotest.Position[]
  local receiver_methods = {} -- Will be renamed
  ---@type neotest.Position[]
  local regular_tests = {}
  ---@type neotest.Position[]
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

  -- Get the current file's package name from lookup table
  ---@type string | nil
  local current_package = nil
  for file_path, file_data in pairs(global_lookup_table) do
    if file_path == tree:data().path then
      current_package = file_data.package
      break
    end
  end

  -- Process receiver methods: rename IDs to SuiteName/MethodName format
  for _, method_pos in ipairs(receiver_methods) do
    -- Find which receiver this method belongs to
    ---@type string | nil
    local receiver_type = nil
    ---@type string | nil
    local suite_function_name = nil

    for _, instance in ipairs(method_positions[method_pos.name] or {}) do
      if method_pos.range then
        ---@type number
        local method_start_line = method_pos.range[1]
        ---@type number
        local method_end_line = method_pos.range[3]

        if instance.definition and instance.definition.node then
          ---@type TSNode
          local node = instance.definition.node
          ---@type number, number, number, number
          local start_row, _, end_row, _ = node:range()

          -- Check if this instance's node matches this position
          if start_row <= method_end_line and end_row >= method_start_line then
            receiver_type = instance.receiver
            -- Find suite function for this receiver
            for recv, suite_func in pairs(replacements) do
              if recv == receiver_type then
                -- Verify package matches to avoid cross-package collisions
                local recv_package = recv:match("^([^%.]+)%.")
                if recv_package == current_package then
                  suite_function_name = suite_func
                  break
                end
              end
            end
            break
          end
        end
      end
    end

    if suite_function_name then
      -- Rename method ID: ::MethodName -> ::SuiteName/MethodName
      ---@type string
      local pattern = "::" .. method_pos.name .. "$"
      ---@type string
      local replacement = "::" .. suite_function_name .. "/" .. method_pos.name
      method_pos.id = method_pos.id:gsub(pattern, replacement)

      -- Process subtests for this method
      ---@type neotest.Tree[]
      local method_children = {}
      for _, subtest_pos in ipairs(subtests) do
        -- Check if this subtest belongs to this method
        -- Original subtest ID: path::MethodName::"SubtestName"
        -- Need to update to: path::SuiteName/MethodName::"SubtestName"
        local subtest_pattern = "::"
          .. method_pos.name:match("([^/]+)$")
          .. "::"
        if subtest_pos.id:find(subtest_pattern, 1, true) then
          -- Update subtest ID to match new parent format
          -- Keep :: separator before subtest name (required for convert.lua)
          subtest_pos.id = subtest_pos.id:gsub(
            "::" .. method_pos.name:match("([^/]+)$") .. "::",
            "::"
              .. suite_function_name
              .. "/"
              .. method_pos.name:match("([^/]+)$")
              .. "::"
          )
          table.insert(method_children, create_tree_node(subtest_pos, {}))
        end
      end

      table.insert(root_children, create_tree_node(method_pos, method_children))
    else
      -- If we can't find a suite function, treat as regular test
      table.insert(root_children, create_tree_node(method_pos, {}))
    end
  end

  -- Add regular tests with their subtests
  for _, test_pos in ipairs(regular_tests) do
    ---@type neotest.Tree[]
    local test_children = {}

    -- Find subtests that belong to this regular test
    for _, subtest_pos in ipairs(subtests) do
      -- Check if this subtest belongs to this test
      if subtest_pos.id:find("::" .. test_pos.name .. "::", 1, true) then
        -- Make sure it's not a suite subtest (already processed above)
        local already_processed = false
        for _, suite_pos in pairs(suite_functions) do
          if subtest_pos.id:find("/" .. suite_pos.name .. "/", 1, true) then
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

  -- Note: Suite functions are NOT added to the tree (they are hidden)

  -- Sort children by line number to ensure tree iteration order matches file line order
  -- This is critical for Neotest's "nearest test" algorithm to work correctly
  table.sort(root_children, function(a, b)
    local a_pos = a:data()
    local b_pos = b:data()
    -- Use range start line for comparison
    if a_pos.range and b_pos.range then
      return a_pos.range[1] < b_pos.range[1]
    end
    return false
  end)

  -- Create new tree with file as root and updated children
  return create_tree_node(file_pos, root_children)
end

return M
