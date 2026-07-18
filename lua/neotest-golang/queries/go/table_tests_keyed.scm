; ============================================================================
; RESPONSIBILITY: Table-test cases with keyed struct fields (element-scoped)
; ============================================================================
; Detects individual table-test cases whose struct literal uses keyed fields,
; e.g. {name: "test1", want: 42}. Covers all keyed slice shapes:
;   - named variable:   tt := []T{ {name: "x"}, ... }
;   - inline slice:      for _, tc := range []struct{...}{ {name: "x"}, ... }
;   - pointer slice:     for _, tt := range []*User{ {Name: "x"}, ... }
;
; This query is intentionally ELEMENT-SCOPED: it matches each struct element on
; its own and does NOT also match the surrounding `for ... t.Run(...)` loop.
; Binding every element to the trailing loop makes tree-sitter hold one
; in-progress match per element until the loop is reached, and once the match
; limit is exceeded the leading matches are dropped (issue #581). Matching each
; element independently keeps matches from accumulating, so tables of any size
; are detected in full.
;
; The loop validation the combined query used to do in tree-sitter (that a
; `t.Run(v.<field>, ...)` call actually runs this field as a subtest) is instead
; performed in Lua, in query._build_position via lib/tabletest.lua.
;
; What gets captured:
; - @test.name            = The string value of the field (e.g. "test1")
; - @test.definition      = The entire struct element (e.g. {name: "test1"})
; - @test.tabletest.field = The field identifier (e.g. "name"); also marks this
;                           match as a slice table-test case to be validated.
;
; Both a keyed field name and a string literal value are required, so unrelated
; keyed elements (e.g. map values or non-string fields) are not matched.
; ============================================================================
(literal_element
  (literal_value
    (keyed_element
      (literal_element
        (identifier) @test.tabletest.field)
      (literal_element
        (interpreted_string_literal) @test.name)))) @test.definition
