; ============================================================================
; RESPONSIBILITY: Testify suite subtests (DEPRECATED - NOT USED)
; ============================================================================
; This query file is kept for backward compatibility but is NO LONGER LOADED.
;
; HISTORICAL CONTEXT:
; Originally, testify suite subtests (s.Run(), suite.Run()) were detected here.
; However, this caused conflicts with regular Go subtests (t.Run()) because:
; - Both patterns have identical AST structure
; - Both use the same capture names (@test.operand, @test.name, etc.)
; - When loaded separately, tree-sitter would override one with the other
;
; CURRENT SOLUTION:
; Testify suite subtest detection is now combined with regular Go subtest
; detection in queries/test_function.scm using the pattern:
;   (#match? @test.operand "^(t|s|suite)$")
;
; This allows both t.Run() and suite.Run() to be detected simultaneously
; when testify_enabled = true.
;
; SEE: lua/neotest-golang/queries/test_function.scm for the active implementation
; SEE: lua/neotest-golang/query.lua where testify.query.subtest_query is NOT loaded
; ============================================================================

; query for subtest, like s.Run(), suite.Run()
(call_expression
  function: (selector_expression
    operand: (identifier) @test.operand (#match? @test.operand "%s")
    field: (field_identifier) @test.method) (#match? @test.method "^Run$"
  )
  arguments: (argument_list . (interpreted_string_literal) @test.name)
) @test.definition

