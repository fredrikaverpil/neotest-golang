; ============================================================================
; RESPONSIBILITY: Inline unkeyed table tests (no variable, positional fields)
; ============================================================================
; Detects table tests that combine two characteristics:
; 1. INLINE: Slice defined directly in for-range (no separate variable)
; 2. UNKEYED: Struct fields use positional syntax (no field names)
;
; Pattern structure:
; 1. Inline slice: for _, tc := range []struct{...}{...}
; 2. Positional fields: {"test1", 1} instead of {name: "test1", want: 1}
; 3. First field must be string type (the test name)
; 4. Loop body: t.Run(tc.name, ...)
;
; Example with captures:
;   for _, tc := range []struct{
;     name string
;     want int
;   }{
;     {"test1", 1},  // @test.name = "test1", @test.definition = entire struct
;     {"test2", 2},  // No "name:" - values assigned by position
;   } {
;     t.Run(tc.name, func(t *testing.T) { ... })
;   }
;
; What gets captured:
; - @test.name = The first string literal (e.g., "test1")
; - @test.definition = The entire struct literal (e.g., {"test1", 1})
; - @test.field.name = The first field identifier from struct type (e.g., "name")
;
; DISTINGUISHING FEATURES:
; - No variable: tt := []struct{} (compare to table_tests_unkeyed.scm)
; - No field keys: {name: "test1"} (compare to table_tests_loop.scm)
; ============================================================================
(for_statement
  (range_clause
    left: (expression_list
      (identifier)
      (identifier) @test.case)
    right: (composite_literal
      type: (slice_type
        element: (struct_type
          (field_declaration_list
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
            (literal_element)) @test.definition))))
  body: (block
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
            (#eq? @test.field.name @test.field.name1)))))))
