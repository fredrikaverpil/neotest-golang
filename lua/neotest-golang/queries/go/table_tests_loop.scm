; ============================================================================
; RESPONSIBILITY: Table-driven tests with inline slice (no variable)
; ============================================================================
; Detects table tests where the test case slice is defined directly in the
; for-range statement (not in a separate variable).
;
; Pattern structure:
; 1. Inline slice: for _, tc := range []struct{...}{...}
; 2. Explicit struct type: []struct{ name string }
; 3. Keyed struct fields: {name: "test1"}
; 4. Loop body: t.Run(tc.name, ...)
;
; Example with captures:
;   for _, tc := range []struct{
;     name string
;     want int
;   }{
;     {name: "test1", want: 1},  // @test.name = "test1", @test.definition = entire struct
;     {name: "test2", want: 2},  // @test.name = "test2", @test.definition = entire struct
;   } {
;     t.Run(tc.name, func(t *testing.T) { ... })
;   }
;
; What gets captured:
; - @test.name = The string value of the name field (e.g., "test1")
; - @test.definition = The entire struct literal (e.g., {name: "test1", want: 1})
; - @test.field.name = The field identifier (e.g., "name")
;
; DISTINGUISHING FEATURE: Slice type is []struct{}, not []*struct{}.
; For pointer slices, see table_tests_inline_field_access.scm.
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
              name: (field_identifier)
              type: (type_identifier)))))
      body: (literal_value
        (literal_element
          (literal_value
            (keyed_element
              (literal_element
                (identifier)) @test.field.name
              (literal_element
                (interpreted_string_literal) @test.name))) @test.definition))))
  body: (block
    (expression_statement
      (call_expression
        function: (selector_expression
          operand: (identifier)
          field: (field_identifier))
        arguments: (argument_list
          (selector_expression
            operand: (identifier)
            field: (field_identifier) @test.field.name1)
          (#eq? @test.field.name @test.field.name1))))))
