; ============================================================================
; RESPONSIBILITY: Map-based table-test cases (element-scoped)
; ============================================================================
; Detects individual table-test cases defined in a map with string keys, where
; the map key is the subtest name:
;   tt := map[string]T{ "test1": {...}, "test2": {...} }
;   for name, tc := range tt { t.Run(name, ...) }
;
; Like the other table_tests_*.scm queries this is ELEMENT-SCOPED (see
; table_tests_keyed.scm and issue #581). Loop validation happens in Lua, in
; query._build_position via lib/tabletest.lua.
;
; What gets captured:
; - @test.name             = The string literal map key (e.g. "test1")
; - @test.definition       = The struct literal value (e.g. {want: 1})
; - @test.tabletest.mapkey = The map key node; marks this match as a map
;                            table-test case (validated against t.Run(key)).
;
; The key must be a string literal and the value a composite literal, which
; distinguishes map cases from keyed slice cases (handled by
; table_tests_keyed.scm, whose keyed fields use identifier keys).
; ============================================================================
(composite_literal
  (literal_value
    (keyed_element
      (literal_element
        (interpreted_string_literal) @test.name) @test.tabletest.mapkey
      (literal_element
        (literal_value) @test.definition))))
