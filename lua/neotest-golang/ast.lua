--- Detect test names in Go *._test.go files.

local lib = require("neotest.lib")

local testify = require("neotest-golang.testify")

local ts = require("nvim-treesitter.ts_utils")
local parsers = require("nvim-treesitter.parsers")

local M = {}

--- Detect test names in Go *._test.go files.
--- @param file_path string
function M.detect_tests(file_path)
  local test_function = [[
    ; query for test function
    ((function_declaration
      name: (identifier) @test.name) (#match? @test.name "^(Test|Example)"))
      @test.definition

    ; query for subtest, like t.Run()
    (call_expression
      function: (selector_expression
        field: (field_identifier) @test.method) (#match? @test.method "^Run$")
      arguments: (argument_list . (interpreted_string_literal) @test.name))
      @test.definition
  ]]

  local test_method = [[
   ; query for test method
   (method_declaration
    name: (field_identifier) @test.name (#match? @test.name "^(Test|Example)")) @test.definition
  ]]

  local receiver_method = [[
  ; query for receiver method, to be used as test suite namespace
   (method_declaration
    receiver: (parameter_list
      (parameter_declaration
        ; name: (identifier)
        type: (pointer_type
          (type_identifier) @namespace.name )))) @namespace.definition
  ]]

  local table_tests = [[
    ;; query for list table tests
        (block
          (short_var_declaration
            left: (expression_list
              (identifier) @test.cases)
            right: (expression_list
              (composite_literal
                (literal_value
                  (literal_element
                    (literal_value
                      (keyed_element
                        (literal_element
                          (identifier) @test.field.name)
                        (literal_element
                          (interpreted_string_literal) @test.name)))) @test.definition))))
          (for_statement
            (range_clause
              left: (expression_list
                (identifier) @test.case)
              right: (identifier) @test.cases1
                (#eq? @test.cases @test.cases1))
            body: (block
             (expression_statement
              (call_expression
                function: (selector_expression
                  field: (field_identifier) @test.method)
                  (#match? @test.method "^Run$")
                arguments: (argument_list
                  (selector_expression
                    operand: (identifier) @test.case1
                    (#eq? @test.case @test.case1)
                    field: (field_identifier) @test.field.name1
                    (#eq? @test.field.name @test.field.name1))))))))

    ;; query for list table tests (wrapped in loop)
    (for_statement
      (range_clause
          left: (expression_list 
            (identifier)
            (identifier) @test.case ) 
          right: (composite_literal 
            type: (slice_type 
              element: (struct_type 
                (field_declaration_list 
                  (field_declaration 
                    name: (field_identifier) 
                    type: (type_identifier)))))
            body: (literal_value
              (literal_element 
                (literal_value 
                  (keyed_element 
                    (literal_element 
                      (identifier))  @test.field.name 
                    (literal_element 
                      (interpreted_string_literal) @test.name ))
                  ) @test.definition)
              )))
        body: (block 
          (expression_statement 
            (call_expression 
              function: (selector_expression 
                operand: (identifier) 
                field: (field_identifier)) 
              arguments: (argument_list 
                (selector_expression 
                  operand: (identifier) 
                  field: (field_identifier) @test.field.name1) (#eq? @test.field.name @test.field.name1))))))

    ;; query for map table tests 
      (block
          (short_var_declaration
            left: (expression_list
              (identifier) @test.cases)
            right: (expression_list
              (composite_literal
                (literal_value
                  (keyed_element
                  (literal_element
                      (interpreted_string_literal)  @test.name)
                    (literal_element
                      (literal_value)  @test.definition))))))
        (for_statement
           (range_clause
              left: (expression_list
                ((identifier) @test.key.name)
                ((identifier) @test.case))
              right: (identifier) @test.cases1
                (#eq? @test.cases @test.cases1))
            body: (block
               (expression_statement
                (call_expression
                  function: (selector_expression
                    field: (field_identifier) @test.method)
                    (#match? @test.method "^Run$")
                    arguments: (argument_list
                    ((identifier) @test.key.name1
                    (#eq? @test.key.name @test.key.name1))))))))
  ]]

  local query = test_function .. test_method .. table_tests .. receiver_method
  local opts = { nested_tests = true }

  ---@type neotest.Tree
  local tree = lib.treesitter.parse_positions(file_path, query, opts)

  -- HACK: code below for testify suite support.
  -- TODO: hide functionality behind opt-in option.
  local tree_with_merged_namespaces =
    testify.merge_duplicate_namespaces(tree:root())
  local testify_query = [[
  ; query
  (function_declaration ; [38, 0] - [40, 1]
    name: (identifier) @testify.function_name ; [38, 5] - [38, 14]
    ;parameters: (parameter_list ; [38, 14] - [38, 28]
    ;  (parameter_declaration ; [38, 15] - [38, 27]
    ;    name: (identifier) ; [38, 15] - [38, 16]
    ;    type: (pointer_type ; [38, 17] - [38, 27]
    ;      (qualified_type ; [38, 18] - [38, 27]
    ;        package: (package_identifier) ; [38, 18] - [38, 25]
    ;        name: (type_identifier))))) ; [38, 26] - [38, 27]
    body: (block ; [38, 29] - [40, 1]
      (expression_statement ; [39, 1] - [39, 34]
        (call_expression ; [39, 1] - [39, 34]
          function: (selector_expression ; [39, 1] - [39, 10]
            operand: (identifier) @testify.module ; [39, 1] - [39, 6]
            field: (field_identifier) @testify.run ) @testify.call ; [39, 7] - [39, 10]
          arguments: (argument_list ; [39, 10] - [39, 34]
            (identifier) @testify.t ; [39, 11] - [39, 12]
            (call_expression ; [39, 14] - [39, 33]
              function: (identifier) ; [39, 14] - [39, 17]
              arguments: (argument_list ; [39, 17] - [39, 33]
                (type_identifier) @testify.receiver ))))))) @testify.definition
  ]]

  local testify_nodes = testify.run_query_on_file(file_path, testify_query)

  for test_function, data in pairs(testify_nodes) do
    local function_name = nil
    local receiver = nil
    for _, node in ipairs(data) do
      if node.name == "testify.function_name" then
        function_name = node.text
      end
      if node.name == "testify.receiver" then
        receiver = node.text
      end
    end
    testify.add(file_path, function_name, receiver) -- FIXME: accumulates forever
  end

  return tree_with_merged_namespaces
end

return M
