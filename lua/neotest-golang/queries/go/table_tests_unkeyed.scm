; ============================================================================
; RESPONSIBILITY: Table tests with unkeyed (positional) struct fields
; ============================================================================
; Detects table tests where struct literals use positional syntax instead of
; field names. Fields are assigned by position, not by name.
;
; Pattern structure:
; 1. Variable declaration: tt := []struct{ name string; want int }{...}
; 2. Unkeyed fields: {"test1", 1} instead of {name: "test1", want: 1}
; 3. First field must be a string (the test name)
; 4. For loop: for _, tc := range tt
; 5. Loop body: t.Run(tc.name, ...)
;
; Example with captures:
;   tt := []struct{
;     name string
;     want int
;   }{
;     {"test1", 1},  // @test.name = "test1", @test.definition = entire struct
;     {"test2", 2},  // No "name:" prefix - values assigned by position
;   }
;   for _, tc := range tt {
;     t.Run(tc.name, func(t *testing.T) { ... })
;   }
;
; What gets captured:
; - @test.name = The first string literal in the struct (e.g., "test1")
; - @test.definition = The entire struct literal (e.g., {"test1", 1})
; - @test.field.name = The first string field from struct type (e.g., "name")
;
; The query validates that the field used in t.Run() matches the first string
; field declared in the struct type. This prevents capturing wrong string
; literals when the struct has multiple string fields.
;
; DISTINGUISHING FEATURE: No field names in the struct literal.
; Compare to table_tests_list.scm which uses {name: "test1"} syntax.
; ============================================================================
(block
  (statement_list
    (short_var_declaration
      left: (expression_list
        (identifier) @test.cases)
      right: (expression_list
        (composite_literal
          type: (slice_type
            element: (struct_type
              (field_declaration_list
                .
                (field_declaration
                  name: (field_identifier) @test.field.name
                  type: (type_identifier) @field.type
                  (#eq? @field.type "string")))))
          body: (literal_value
            (literal_element
              (literal_value
                .
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
                  (#eq? @test.case @test.case1)
                  field: (field_identifier) @test.field.name1
                  (#eq? @test.field.name @test.field.name1))))))))))
