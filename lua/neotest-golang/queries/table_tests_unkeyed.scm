; ============================================================================
; RESPONSIBILITY: Table tests with unkeyed (positional) struct literals
; ============================================================================
; Detects table tests where:
; 1. Test cases use positional (unkeyed) field syntax
; 2. Cases are in a named slice variable: tt := []struct{...}
; 3. First field is the test name (string literal)
; 4. Loop accesses the test case variable directly in t.Run()
;
; Example pattern:
;   tt := []struct{
;     name string
;     want int
;   }{
;     {"test1", 1},  // ← unkeyed: fields in order, no "name:"
;   }
;   for _, tc := range tt {
;     t.Run(tc.name, func(t *testing.T) { ... })
;   }
;
; DISTINGUISHING FEATURE: literal_element without keyed_element wrapper.
; The first string literal is assumed to be the test name.
; ============================================================================

; query for table tests with inline structs (not keyed)
(block
  (statement_list
    (short_var_declaration
      left: (expression_list
        (identifier) @test.cases)
      right: (expression_list
        (composite_literal
          body: (literal_value
            (literal_element
              (literal_value
                (literal_element
                  (interpreted_string_literal) @test.name)
                (literal_element)) @test.definition)))))
    (for_statement
      (range_clause
        left: (expression_list
          (identifier) @test.key.name
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
                  (#eq? @test.case @test.case1))))))))))

