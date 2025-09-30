; ============================================================================
; RESPONSIBILITY: Table-driven tests with explicit slice variable
; ============================================================================
; Detects table tests where:
; 1. Test cases are defined in a named slice variable: tt := []TestCase{...}
; 2. Cases are iterated with for-range loop: for _, tc := range tt { ... }
; 3. Each case has a "name" field accessed in t.Run(tc.name, ...)
;
; Example pattern:
;   tt := []struct{ name string }{
;     {name: "test1"},
;   }
;   for _, tc := range tt {
;     t.Run(tc.name, func(t *testing.T) { ... })
;   }
;
; SCOPE: Matches the test case definitions (the slice elements), not the loop.
; The loop body is validated to ensure it calls t.Run with the same field name.
; ============================================================================

; query for list table tests
(block
  (statement_list
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
                  field: (field_identifier) @test.field.name1
                  (#eq? @test.field.name @test.field.name1))))))))))
