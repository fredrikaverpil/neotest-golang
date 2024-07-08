--- Opt-in functionality to support testify suites.
--- See https://github.com/stretchr/testify for more info.

local parsers = require("nvim-treesitter.parsers")

local M = {}
local lookup_map = {}

M.lookup_query = [[
  ; query for detecting package, struct and test suite, for use in lookup.
  (package_clause
    (package_identifier) @package)
  (type_declaration
    (type_spec
      name: (type_identifier) @struct_name
      type: (struct_type)))
  (method_declaration
    receiver: (parameter_list
      (parameter_declaration
        type: (pointer_type
          (type_identifier) @receiver_type)))
    name: (field_identifier) @method_name)
  (function_declaration
    name: (identifier) @function_name)
  (call_expression
    function: (selector_expression
      operand: (identifier) @module
      field: (field_identifier) @run (#eq? @run "Run"))
    arguments: (argument_list
      (identifier)
      (call_expression
        arguments: (argument_list
          (type_identifier) @suite_receiver))))
  ]]

M.receiver_method_query = [[
  ; query for receiver method, to be used as test suite namespace.
   (method_declaration
    receiver: (parameter_list
      (parameter_declaration
        ; name: (identifier)
        type: (pointer_type
          (type_identifier) @namespace.name )))) @namespace.definition
  ]]

---@param file_path string
---@param tree neotest.Tree
function M.modify_neotest_tree(file_path, tree)
  local lookup = M.get_lookup_map()

  if not lookup then
    return tree
  end

  local modified_tree = M.replace_receiver_with_suite(tree:root(), lookup)
  local tree_with_merged_namespaces = M.merge_duplicate_namespaces(tree:root())
  return tree_with_merged_namespaces
end

function M.get_lookup_map()
  if vim.tbl_isempty(lookup_map) then
    lookup_map = M.generate_lookup_map()
  end
  return lookup_map
end

function M.add_to_lookup_map(file_name, package_name, suite_name, receiver_name)
  if not lookup_map[file_name] then
    lookup_map[file_name] = {}
  end
  local new_entry = {
    package = package_name,
    suite = suite_name,
    receiver = receiver_name,
  }
  -- Check if entry already exists
  for _, entry in ipairs(lookup_map[file_name]) do
    if
      entry.package == new_entry.package
      and entry.suite == new_entry.suite
      and entry.receiver == new_entry.receiver
    then
      return
    end
  end
  table.insert(lookup_map[file_name], new_entry)
end

function M.clear_lookup_map()
  lookup_map = {}
end

function M.generate_lookup_map()
  -- local example = {
  --   ["/path/to/file1_test.go"] = {
  --     package = "main",
  --     receivers = { receiverStruct = true, receiverStruct2 = true },
  --     suites = {
  --       receiverStruct = "TestSuite",
  --       receiverStruct2 = "TestSuite2",
  --     },
  --   },
  --   ["/path/to/file2_test.go"] = {
  --     package = "main",
  --     receivers = { receiverStruct3 = true },
  --     suites = {
  --       receiverStruct3 = "TestSuite3",
  --     },
  --   },
  --   -- ... other files ...
  -- }

  local cwd = vim.fn.getcwd()
  local go_files = M.get_go_files(cwd)
  local lookup = {}
  local global_suites = {}

  -- First pass: collect all receivers and suites
  for _, filepath in ipairs(go_files) do
    local matches = M.run_query_on_file(filepath, M.lookup_query)
    local package_name = matches.package
        and matches.package[1]
        and matches.package[1].text
      or "unknown"

    lookup[filepath] = {
      package = package_name,
      receivers = {},
      suites = {},
    }

    -- Collect all receivers
    for _, struct in ipairs(matches.struct_name or {}) do
      lookup[filepath].receivers[struct.text] = true
    end

    -- Collect all test suite functions and their receivers
    for _, func in ipairs(matches.function_name or {}) do
      if func.text:match("^Test") then
        for _, node in ipairs(matches.suite_receiver or {}) do
          lookup[filepath].suites[node.text] = func.text
          global_suites[node.text] = func.text
        end
      end
    end
  end

  -- Second pass: ensure all files have all receivers and suites
  for filepath, file_data in pairs(lookup) do
    for receiver, suite in pairs(global_suites) do
      if not file_data.receivers[receiver] and file_data.suites[receiver] then
        file_data.receivers[receiver] = true
      end
    end
  end

  return lookup
end

-- Function to get all .go files in a directory recursively
function M.get_go_files(directory)
  local files = {}
  local function scan_dir(dir)
    local p = io.popen('find "' .. dir .. '" -type f -name "*_test.go"')
    for file in p:lines() do
      table.insert(files, file)
    end
  end
  scan_dir(directory)
  return files
end

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
