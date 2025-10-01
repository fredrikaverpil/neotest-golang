; ============================================================================
; RESPONSIBILITY: Table-driven tests with inline slice of structs
; ============================================================================
; Detects table tests where:
; 1. Test cases are defined inline in the for-range statement
; 2. The slice has an explicit struct type: []struct{ name string }
; 3. Each case has keyed fields: {name: "test1"}
; 4. Loop body calls t.Run or similar with field access: tc.name
;
; Example pattern:
;   for _, tc := range []struct{
;     name string
;     want int
;   }{
;     {name: "test1", want: 1},
;   } {
;     t.Run(tc.name, func(t *testing.T) { ... })
;   }
;
; DISTINGUISHING FEATURE: Requires explicit struct type in the slice type.
; This distinguishes it from table_tests_inline_field_access which uses pointer types.
; ============================================================================

; query for list table tests (wrapped in loop)
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
    (statement_list
      (expression_statement
        (call_expression
          function: (selector_expression
            operand: (identifier)
            field: (field_identifier))
          arguments: (argument_list
            (selector_expression
              operand: (identifier)
              field: (field_identifier) @test.field.name1)
            (#eq? @test.field.name @test.field.name1)))))))
