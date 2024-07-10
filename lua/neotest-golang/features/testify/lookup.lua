--- Lookup table for testify suite receivers/suite names.

local find = require("neotest-golang.find")
local query = require("neotest-golang.features.testify.query")

local M = {}

--- The lookup map which is required for running testify suites and their tests.
--- @type table<string, table>
local lookup_map = {}

--- Get the current lookup map, generating it if empty.
--- @return table<string, table> The lookup map containing testify suite information
function M.get()
  if vim.tbl_isempty(lookup_map) then
    lookup_map = M.generate()
  end
  return lookup_map
end

--- Generate the lookup map for testify suites.
--- @return table<string, table> The generated lookup map
function M.generate()
  local cwd = vim.fn.getcwd()
  local filepaths = find.go_test_filepaths(cwd)
  local lookup = {}
  local global_suites = {}

  -- First pass: collect all receivers and suites
  for _, filepath in ipairs(filepaths) do
    local matches = query.run_query_on_file(filepath, M.query)

    local package_name = matches.package
        and matches.package[1]
        and matches.package[1].text
      or "unknown"

    lookup[filepath] = {
      package = package_name,
      receivers = {},
      suites = {},
    }

    -- Collect all receivers (same name as suite structs)
    for _, struct in ipairs(matches.suite_struct or {}) do
      lookup[filepath].receivers[struct.text] = true
    end

    -- Collect all test suite functions and their receivers
    for _, func in ipairs(matches.test_function or {}) do
      for _, node in ipairs(matches.suite_struct or {}) do
        lookup[filepath].suites[node.text] = func.text
        global_suites[node.text] = func.text
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

--- Add a new entry to the lookup map.
--- @param file_name string The name of the file
--- @param package_name string The name of the package
--- @param suite_name string The name of the test suite
--- @param receiver_name string The name of the receiver
function M.add(file_name, package_name, suite_name, receiver_name)
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

--- Clear the lookup map.
function M.clear()
  lookup_map = {}
end

--- TreeSitter query for identifying testify suites and their components.
--- @type string
M.query = [[
  ; query for the lookup between receiver and test suite.

  ; package main  // @package
  (package_clause
    (package_identifier) @package)

  ; func TestSuite(t *testing.T) {  // @test_function
  ;   suite.Run(t, new(testSuitestruct))  // @suite_lib, @run_method, @suite_receiver
  ; }
  (function_declaration
    name: (identifier) @test_function (#match? @test_function "^Test")
    body: (block
      (expression_statement
        (call_expression
          function: (selector_expression
            operand: (identifier) @suite_lib (#eq? @suite_lib "suite")
            field: (field_identifier) @run_method (#eq? @run_method "Run"))
          arguments: (argument_list
            (identifier)
            (call_expression
              arguments: (argument_list
                (type_identifier) @suite_struct)))))))

  ; func TestSuite(t *testing.T) {  // @test_function
  ;   s := &testSuiteStruct{}  // @suite_struct
  ;   suite.Run(t, s) // @suite_lib, @run_method
  ; }
  (function_declaration 
    name: (identifier) @test_function (#match? @test_function "^Test")
    parameters: (parameter_list 
      (parameter_declaration 
        name: (identifier) 
        type: (pointer_type 
          (qualified_type 
            package: (package_identifier) 
            name: (type_identifier))))) 
    body: (block 
      (short_var_declaration 
        left: (expression_list 
          (identifier)) 
        right: (expression_list 
          (unary_expression 
            operand: (composite_literal 
              type: (type_identifier) @suite_struct 
              body: (literal_value))))) 
      (expression_statement 
        (call_expression 
          function: (selector_expression 
            operand: (identifier) @suite_lib (#eq? @suite_lib "suite")
            field: (field_identifier) @run_method (#eq? @run_method "Run"))
          arguments: (argument_list 
            (identifier) 
            (identifier))))))
]]

return M
