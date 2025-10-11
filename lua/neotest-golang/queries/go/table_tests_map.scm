; ============================================================================
; RESPONSIBILITY: Map-based table-driven tests
; ============================================================================
; Detects table tests where test cases are defined in a map with string keys.
;
; Pattern structure:
; 1. Variable declaration: testCases := map[string]TestCase{...}
; 2. Map keys are string literals (the test names)
; 3. Map values are the test case structs
; 4. For loop: for name, tc := range testCases
; 5. Loop body: t.Run(name, ...)
;
; Example with captures:
;   testCases := map[string]struct{ want int }{
;     "test1": {want: 1},  // @test.name = "test1", @test.definition = {want: 1}
;     "test2": {want: 2},  // @test.name = "test2", @test.definition = {want: 2}
;   }
;   for name, tc := range testCases {
;     t.Run(name, func(t *testing.T) { ... })
;   }
;
; What gets captured:
; - @test.name = The string literal map key (e.g., "test1")
; - @test.definition = The struct literal value (e.g., {want: 1})
;
; DISTINGUISHING FEATURE: Uses map[string]T instead of []T.
; The map key becomes the test name, making it unique from slice-based patterns.
; ============================================================================
(block
  (statement_list
    (short_var_declaration
      left: (expression_list
        (identifier) @test.cases)
      right: (expression_list
        (composite_literal
          (literal_value
            (keyed_element
              (literal_element
                (interpreted_string_literal) @test.name)
              (literal_element
                (literal_value) @test.definition))))))
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
                ((identifier) @test.key.name1
                  (#eq? @test.key.name @test.key.name1))))))))))
