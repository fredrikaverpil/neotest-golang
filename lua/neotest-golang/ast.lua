--- Detect test names in Go *._test.go files.

local lib = require("neotest.lib")

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

  local query = test_function .. test_method .. table_tests
  local opts = { nested_tests = true }

  ---@type neotest.Tree
  local positions = lib.treesitter.parse_positions(file_path, query, opts)

  return positions
end

return M
