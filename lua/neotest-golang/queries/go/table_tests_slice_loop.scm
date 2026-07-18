; ============================================================================
; RESPONSIBILITY: Loop validation for slice-based table-test cases
; ============================================================================
; NOT part of the combined test-discovery query. This query is run from
; lua/neotest-golang/lib/tabletest.lua to validate candidate cases matched by
; the element-scoped table_tests_keyed.scm / table_tests_unkeyed.scm queries:
; a struct element only becomes a test position if an enclosing loop ranges
; over its container and runs it as a subtest (see those files and issue #581
; for why validation happens in Lua rather than in the discovery query).
;
; Recognises a table-test loop over a slice:
;   for _, tc := range <src> { ... t.Run(tc.<field>, ...) ... }
;
; The t.Run() operand must be the loop's value variable (#eq? below), so a
; t.Run() call on an unrelated variable does not validate the table.
;
; What gets captured (read by tabletest.lua):
; - @loop      = the for-statement itself (to confirm the validated loop)
; - @range.src = the range expression (composite literal or variable)
; - @run.field = the struct field whose value t.Run() uses as the subtest name
; ============================================================================
(for_statement
  (range_clause
    left: (expression_list
      (identifier)
      (identifier) @_range.val)
    right: (_) @range.src)
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
            (selector_expression
              operand: (identifier) @_run.var
              (#eq? @_run.var @_range.val)
              field: (field_identifier) @run.field))))))) @loop
