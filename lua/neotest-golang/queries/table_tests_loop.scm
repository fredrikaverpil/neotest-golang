; query for list table tests (wrapped in loop)
; This query should NOT match inline anonymous structs with field access in t.Run()
; Those are handled by table_tests_inline_field_access
(for_statement
  (range_clause
    left: (expression_list
      (identifier)
      (identifier) @test.case)
    right: (identifier) @test.cases)
  body: (block
    (statement_list
      (expression_statement
        (call_expression
          function: (selector_expression
            operand: (identifier) @test.operand
            (#match? @test.operand "^[t]$")
            field: (field_identifier) @test.method
            (#match? @test.method "^Run$"))
          arguments: (argument_list
            (selector_expression
              operand: (identifier) @test.case1
              (#eq? @test.case @test.case1)
              field: (field_identifier) @test.field.name)))))))

