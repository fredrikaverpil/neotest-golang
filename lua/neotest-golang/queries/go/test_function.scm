; ============================================================================
; RESPONSIBILITY: Top-level test functions and subtests (both regular and testify)
; ============================================================================
; This file contains two queries:
;
; QUERY 1: Top-level test functions
; Captures: func TestXxx(t *testing.T) and func ExampleXxx()
; - Matches any function starting with "Test" or "Example"
; - Excludes TestMain (special function not run as a test)
;
; Example with captures:
;   func TestExample(t *testing.T) { // @test.name = "TestExample"
;     // test body                   // @test.definition = entire function
;   }
;
; QUERY 2: Subtests created with .Run() method calls
; Captures: t.Run(), s.Run(), or suite.Run() calls
; - Regular Go subtests: t.Run("name", func(t *testing.T) {...})
; - Testify suite subtests: s.Run("name", func() {...})
; - Matches operand "t", "s", or "suite"
;
; Example with captures:
;   t.Run("subtest", func(t *testing.T) { // @test.name = "subtest"
;     // ...                                // @test.definition = entire call
;   })
;
; COMBINED APPROACH: These patterns are in a single file to avoid query conflicts.
; Tree-sitter can't handle duplicate capture names with different predicates across
; files - one would override the other. This is especially important for suite.Run()
; which shares the same AST structure as t.Run().
; ============================================================================
((function_declaration
  name: (identifier) @test.name)
  (#match? @test.name "^(Test|Example)")
  (#not-match? @test.name "^TestMain$")) @test.definition

(call_expression
  function: (selector_expression
    operand: (identifier) @test.operand
    (#match? @test.operand "^(t|s|suite)$")
    field: (field_identifier) @test.method)
  (#match? @test.method "^Run$")
  arguments: (argument_list
    .
    (interpreted_string_literal) @test.name)) @test.definition
