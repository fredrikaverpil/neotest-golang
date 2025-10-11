; ============================================================================
; RESPONSIBILITY: Inline pointer slice table tests
; ============================================================================
; Detects table tests using a slice of pointers defined inline in the loop.
; Pointers are often used when test cases need methods or need to be modified.
;
; Pattern structure:
; 1. Inline pointer slice: for _, tt := range []*Type{...}
; 2. Keyed struct fields: {Name: "test1", ID: 1}
; 3. Field access in t.Run: t.Run(tt.Name, ...)
; 4. Usually uses exported (capitalized) field names
;
; Example with captures:
;   for _, tt := range []*User{
;     {Name: "test1", ID: 1},  // @test.name = "test1", @test.definition = entire struct
;     {Name: "test2", ID: 2},  // @test.field.name = "Name"
;   } {
;     t.Run(tt.Name, func(t *testing.T) { ... })
;   }
;
; What gets captured:
; - @test.name = The string value of the name field (e.g., "test1")
; - @test.definition = The entire struct literal (e.g., {Name: "test1", ID: 1})
; - @test.field.name = The field identifier (e.g., "Name")
;
; DISTINGUISHING FEATURE: Pointer type []*Type instead of []Type.
; This prevents collision with table_tests_loop.scm which handles []struct{}.
;
; HISTORICAL NOTE: Added post-v1.15.1 to support pointer-based table test patterns.
; ============================================================================
(for_statement
  (range_clause
    left: (expression_list
      (identifier)
      (identifier) @test.case)
    right: (composite_literal
      type: (slice_type
        element: (pointer_type))
      body: (literal_value
        (literal_element
          (literal_value
            (keyed_element
              (literal_element
                (identifier) @test.field.name)
              (literal_element
                (interpreted_string_literal) @test.name))) @test.definition))))
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
