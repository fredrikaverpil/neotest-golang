; ============================================================================
; RESPONSIBILITY: Loop validation for map-based table-test cases
; ============================================================================
; NOT part of the combined test-discovery query. This query is run from
; lua/neotest-golang/lib/tabletest.lua to validate candidate cases matched by
; the element-scoped table_tests_map.scm query: a map entry only becomes a
; test position if an enclosing loop ranges over its container and runs it as
; a subtest (see that file and issue #581 for why validation happens in Lua
; rather than in the discovery query).
;
; Recognises a table-test loop over a map, where the subtest name is the map
; key, so t.Run() is called with the range key variable directly:
;   for name, tc := range <src> { ... t.Run(name, ...) ... }
;
; What gets captured (read by tabletest.lua):
; - @loop      = the for-statement itself (to confirm the validated loop)
; - @range.src = the range expression (the variable holding the map)
; ============================================================================
(for_statement
  (range_clause
    left: (expression_list
      .
      (identifier) @_range.key)
    right: (identifier) @range.src)
  body: (block
    (statement_list
      (expression_statement
        (call_expression
          function: (selector_expression
            operand: (identifier) @_run.operand
            (#eq? @_run.operand "t")
            field: (field_identifier) @_run.method
            (#eq? @_run.method "Run"))
          arguments: (argument_list
            .
            (identifier) @_run.arg
            (#eq? @_run.arg @_range.key))))))) @loop
