; ============================================================================
; RESPONSIBILITY: Table-driven tests with named slice variable and keyed fields
; ============================================================================
; Detects table tests where test cases are defined in a named variable with
; keyed struct fields (e.g., {name: "test1"}).
;
; Pattern structure:
; 1. Variable declaration: tt := []struct{ name string }{...}
; 2. Struct fields use keys: {name: "test1", want: 42}
; 3. For loop: for _, tc := range tt
; 4. Loop body: t.Run(tc.name, ...)
;
; Example with captures:
;   tt := []struct{ name string }{
;     {name: "test1"},  // @test.name = "test1", @test.definition = entire struct
;     {name: "test2"},  // @test.name = "test2", @test.definition = entire struct
;   }
;   for _, tc := range tt {
;     t.Run(tc.name, func(t *testing.T) { ... })
;   }
;
; What gets captured:
; - @test.name = The string value of the name field (e.g., "test1")
; - @test.definition = The entire struct literal (e.g., {name: "test1"})
; - @test.field.name = The field identifier (e.g., "name")
;
; The query validates that the same field is used in both the struct and t.Run().
; ============================================================================
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
