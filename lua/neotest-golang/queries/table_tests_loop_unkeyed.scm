; ============================================================================
; RESPONSIBILITY: Inline table tests with unkeyed (positional) struct literals
; ============================================================================
; Detects table tests where:
; 1. Test cases are defined inline in the for-range statement
; 2. Cases use positional (unkeyed) field syntax: {"test1", value}
; 3. The slice has explicit struct type with named fields
; 4. First field must be string type (the test name)
; 5. Loop body calls t.Run with field access: tc.name
;
; Example pattern:
;   for _, tc := range []struct{
;     name string
;     want int
;   }{
;     {"test1", 1},  // ← unkeyed: no field names
;   } {
;     t.Run(tc.name, func(t *testing.T) { ... })
;   }
;
; DISTINGUISHING FEATURES:
; - Inline composite literal (no variable declaration)
; - Unkeyed struct fields
; - First field is validated to be string type
; ============================================================================

; query for table tests with inline structs (not keyed, wrapped in loop)
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
            (literal_element
              (interpreted_string_literal) @test.name)
            (literal_element)) @test.definition))))
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
              (#eq? @test.field.name @test.field.name1))))))))

