--- Lookup table for renaming Neotest namespaces (receiver type to testify suite function).

local find = require("neotest-golang.find")
local query = require("neotest-golang.features.testify.query")

local M = {}

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

--- The lookup table.
--- @type table<string, table>
local lookup_table = {}

--- Get the current lookup table, generating it if empty.
--- @return table<string, table> The lookup table containing testify suite information
function M.get()
  if vim.tbl_isempty(lookup_table) then
    lookup_table = M.generate()
  end
  return lookup_table
end

--- Generate the lookup table for testify suites.
--- @return table<string, table> The generated lookup table
function M.generate()
  local cwd = vim.fn.getcwd()
  local filepaths = find.go_test_filepaths(cwd)
  local lookup = {}
  -- local global_suites = {}

  -- First pass: collect all data for the lookup table.
  for _, filepath in ipairs(filepaths) do
    local matches = query.run_query_on_file(filepath, M.query)

    local package_name = matches.package
        and matches.package[1]
        and matches.package[1].text
      or "unknown"

    lookup[filepath] = {
      package = package_name,
      replacements = {},
    }

    for i, struct in ipairs(matches.suite_struct or {}) do
      local func = matches.test_function[i]
      if func then
        lookup[filepath].replacements[struct.text] = func.text
      end
    end
  end

  return lookup
end

--- Clear the lookup table.
function M.clear()
  lookup_table = {}
end

return M
