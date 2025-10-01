; ============================================================================
; RESPONSIBILITY: Inline pointer slice table tests with field access
; ============================================================================
; Detects table tests where:
; 1. Test cases are defined inline as a slice of pointers: []*Type{...}
; 2. Cases are defined inline in the for-range statement (no variable)
; 3. Each case uses keyed fields: {Name: "test1", ...}
; 4. Loop body calls t.Run with field access to EXPORTED field: tt.Name
;
; Example pattern:
;   for _, tt := range []*User{
;     {Name: "test1", ID: 1},
;     {Name: "test2", ID: 2},
;   } {
;     t.Run(tt.Name, func(t *testing.T) { ... })
;   }
;
; DISTINGUISHING FEATURES:
; - Requires pointer type in slice: []*Type (not []Type)
; - This prevents duplicate matching with table_tests_loop.scm
; - Typically used when test cases need to be modified or have methods
; - Field accessed in t.Run is usually an exported (capitalized) field
;
; HISTORICAL NOTE: Added post-v1.15.1 to support pointer-based table test patterns.
; ============================================================================

; query for table tests with inline composite literal and field access for test name
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
