--- Detect test names in Go *._test.go files.

local lib = require("neotest.lib")

local options = require("neotest-golang.options")
local testify = require("neotest-golang.features.testify")

local M = {}

M.test_function = [[
  ;; query for test function
  (
    (function_declaration
      name: (identifier) @test.name
    ) (#match? @test.name "^(Test|Example)") (#not-match? @test.name "^TestMain$")
  ) @test.definition

  ; query for subtest, like t.Run()
  (call_expression
    function: (selector_expression
      operand: (identifier) @test.operand (#match? @test.operand "^[t]$")
      field: (field_identifier) @test.method) (#match? @test.method "^Run$"
    )
    arguments: (argument_list . (interpreted_string_literal) @test.name)
  ) @test.definition
]]

M.table_tests_list = [[
  ;; query for list table tests
  (block
    (short_var_declaration
      left: (expression_list
        (identifier) @test.cases
      )
      right: (expression_list
        (composite_literal
          (literal_value
            (literal_element
              (literal_value
                (keyed_element
                  (literal_element
                    (identifier) @test.field.name
                  )
                  (literal_element
                    (interpreted_string_literal) @test.name
                  )
                )
              )
            ) @test.definition
          )
        )
      )
    )
    (for_statement
      (range_clause
        left: (expression_list
          (identifier) @test.case
        )
        right: (identifier) @test.cases1 (#eq? @test.cases @test.cases1)
      )
      body: (block
        (expression_statement
          (call_expression
            function: (selector_expression
              operand: (identifier) @test.operand (#match? @test.operand "^[t]$")
              field: (field_identifier) @test.method (#match? @test.method "^Run$")
            )
            arguments: (argument_list
              (selector_expression
                operand: (identifier) @test.case1 (#eq? @test.case @test.case1)
                field: (field_identifier) @test.field.name1 (#eq? @test.field.name @test.field.name1)
              )
            )
          )
        )
      )
    )
  )
]]

M.table_tests_loop = [[
  ;; query for list table tests (wrapped in loop)
  (for_statement
    (range_clause
      left: (expression_list
        (identifier)
        (identifier) @test.case
      )
      right: (composite_literal
        type: (slice_type
          element: (struct_type
            (field_declaration_list
              (field_declaration
                name: (field_identifier)
                type: (type_identifier)
              )
            )
          )
        )
        body: (literal_value
          (literal_element
            (literal_value
              (keyed_element
                (literal_element
                  (identifier)
                )  @test.field.name
                (literal_element
                  (interpreted_string_literal) @test.name
                )
              )
            ) @test.definition
          )
        )
      )
    )
    body: (block
      (expression_statement
        (call_expression
          function: (selector_expression
            operand: (identifier)
            field: (field_identifier)
          )
          arguments: (argument_list
            (selector_expression
              operand: (identifier)
              field: (field_identifier) @test.field.name1
            ) (#eq? @test.field.name @test.field.name1)
          )
        )
      )
    )
  )
]]

M.table_tests_unkeyed = [[
  ;; query for table tests with inline structs (not keyed)
  (block
    (short_var_declaration
      left: (expression_list (identifier) @test.cases
      )
      right: (expression_list
        (composite_literal
          body: (literal_value
            (literal_element
              (literal_value
                (literal_element
                  (interpreted_string_literal) @test.name
                )
                (literal_element)
              ) @test.definition
            )
          )
        )
      )
    )
    (for_statement
      (range_clause
        left: (expression_list
          (
            (identifier) @test.key.name
          )
          (
            (identifier) @test.case
          )
        )
        right: (identifier) @test.cases1 (#eq? @test.cases @test.cases1)
      )
      body: (block
        (expression_statement
          (call_expression
            function: (selector_expression
              operand: (identifier) @test.operand (#match? @test.operand "^[t]$")
              field: (field_identifier) @test.method (#match? @test.method "^Run$")
            )
            arguments: (argument_list
              (selector_expression
                operand: (identifier) @test.case1 (#eq? @test.case @test.case1)
              )
            )
          )
        )
      )
    )
  )
]]

M.table_tests_loop_unkeyed = [[
  ;; query for table tests with inline structs (not keyed, wrapped in loop)
  (for_statement
    (range_clause
      left: (expression_list
        (identifier)
        (identifier) @test.case
      )
      right: (composite_literal
        type: (slice_type
          element: (struct_type
            (field_declaration_list
              (field_declaration
                name: (field_identifier) @test.field.name
                type: (type_identifier) @field.type (#eq? @field.type "string")
              )
            )
          )
        )
        body: (literal_value
          (literal_element
            (literal_value
              (literal_element
                (interpreted_string_literal) @test.name
              )
              (literal_element)
            ) @test.definition
          )
        )
      )
    )
    body: (block
      (expression_statement
        (call_expression
          function: (selector_expression
            operand: (identifier) @test.operand (#match? @test.operand "^[t]$")
            field: (field_identifier) @test.method (#match? @test.method "^Run$")
          )
          arguments: (argument_list
            (selector_expression
              operand: (identifier) @test.case1 (#eq? @test.case @test.case1)
              field: (field_identifier) @test.field.name1 (#eq? @test.field.name @test.field.name1)
            )
          )
        )
      )
    )
  )
]]

M.table_tests_map = [[
  ;; query for map table tests
  (block
    (short_var_declaration
      left: (expression_list
        (identifier) @test.cases
      )
      right: (expression_list
        (composite_literal
          (literal_value
            (keyed_element
              (literal_element
                (interpreted_string_literal)  @test.name
              )
              (literal_element
                (literal_value)  @test.definition
              )
            )
          )
        )
      )
    )
    (for_statement
       (range_clause
          left: (expression_list
            (
              (identifier) @test.key.name
            )
            (
              (identifier) @test.case
            )
          )
          right: (identifier) @test.cases1 (#eq? @test.cases @test.cases1)
        )
        body: (block
         (expression_statement
          (call_expression
            function: (selector_expression
              operand: (identifier) @test.operand (#match? @test.operand "^[t]$")
              field: (field_identifier) @test.method (#match? @test.method "^Run$")
            )
            arguments: (argument_list
              (
                (identifier) @test.key.name1 (#eq? @test.key.name @test.key.name1)
              )
            )
          )
        )
      )
    )
  )
]]

--- Detect test names in Go *._test.go files.
--- @param file_path string
function M.detect_tests(file_path)
  local opts = { nested_tests = true }
  local query = M.test_function
    .. M.table_tests_list
    .. M.table_tests_loop
    .. M.table_tests_unkeyed
    .. M.table_tests_loop_unkeyed
    .. M.table_tests_map

  if options.get().testify_enabled == true then
    -- detect receiver types (as namespaces) and test methods.
    query = query
      .. testify.query.namespace_query
      .. testify.query.test_method_query
      .. testify.query.subtest_query
  end

  ---@type neotest.Tree
  local tree = lib.treesitter.parse_positions(file_path, query, opts)

  if options.get().testify_enabled == true then
    tree = testify.tree_modification.modify_neotest_tree(file_path, tree)
  end

  return tree
end

return M
