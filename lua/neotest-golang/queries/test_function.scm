; ============================================================================
; RESPONSIBILITY: Top-level test functions and subtests (both regular and testify)
; ============================================================================
; This query detects:
; 1. Top-level test functions: func TestXxx(t *testing.T) and func ExampleXxx()
;    - Matches any function starting with "Test" or "Example"
;    - Excludes TestMain (special function not run as a test)
;
; 2. Subtests created with .Run() method calls:
;    - Regular Go subtests: t.Run("name", func(t *testing.T) {...})
;    - Testify suite subtests: s.Run("name", func() {...}) or suite.Run("name", ...)
;    - The operand pattern "^(t|s|suite)$" matches all three common variable names
;
; COMBINED APPROACH: These patterns are combined in a single file to avoid
; query conflicts. When separate, tree-sitter would see duplicate capture names
; with different predicates, causing one to override the other.
;
; NOTE: suite.Run() detection is intentionally in this file, not in the testify
; feature's queries. This is because both t.Run() and suite.Run() share the same
; AST structure and capture names. Having them in separate files would cause
; conflicts where one pattern would override the other, preventing proper detection
; of both regular and testify subtests simultaneously.
; ============================================================================

; query for test function
((function_declaration
  name: (identifier) @test.name)
  (#match? @test.name "^(Test|Example)")
  (#not-match? @test.name "^TestMain$")) @test.definition

; query for subtest, like t.Run(), s.Run(), suite.Run()
(call_expression
  function: (selector_expression
    operand: (identifier) @test.operand
    (#match? @test.operand "^(t|s|suite)$")
    field: (field_identifier) @test.method)
  (#match? @test.method "^Run$")
  arguments: (argument_list
    .
    (interpreted_string_literal) @test.name)) @test.definition
