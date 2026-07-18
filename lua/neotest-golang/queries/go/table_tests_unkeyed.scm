; ============================================================================
; RESPONSIBILITY: Table-test cases with unkeyed (positional) fields
; ============================================================================
; Detects individual table-test cases whose struct literal uses positional
; syntax instead of field names, e.g. {"test1", 1} rather than
; {name: "test1", want: 1}. Covers both the named-variable and inline shapes:
;   - named variable:   tt := []struct{ name string; ... }{ {"x", 1}, ... }
;   - inline slice:      for _, tc := range []struct{...}{ {"x", 1}, ... }
;
; Like table_tests_keyed.scm this query is ELEMENT-SCOPED (see that file and
; issue #581 for why the surrounding loop is not part of the match). Loop
; validation happens in Lua, in query._build_position via lib/tabletest.lua.
;
; The struct type must be defined INLINE (an anonymous struct) and its FIRST
; field must be a string; that first field is treated as the subtest name. This
; mirrors the previous behaviour and its known limitations:
;   - a named struct type ([]tc, not []struct{...}) is not matched, because the
;     field names are not visible at the literal, so the correct name field
;     cannot be validated;
;   - only the first string field is captured, so tables whose t.Run() uses a
;     later string field are not detected.
;
; What gets captured:
; - @test.name            = The first string literal in the element (e.g. "x")
; - @test.definition      = The entire struct element (e.g. {"x", 1})
; - @test.tabletest.field = The first string field name from the struct type
;                           (e.g. "name"); also marks this as a slice table-test
;                           case to be validated.
; ============================================================================
(composite_literal
  type: (slice_type
    element: (struct_type
      (field_declaration_list
        .
        (field_declaration
          name: (field_identifier) @test.tabletest.field
          type: (type_identifier) @_field.type
          (#eq? @_field.type "string")))))
  body: (literal_value
    (literal_element
      (literal_value
        .
        (literal_element
          (interpreted_string_literal) @test.name)
        (literal_element)) @test.definition)))
