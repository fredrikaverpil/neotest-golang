; ============================================================================
; RESPONSIBILITY: Testify suite test methods
; ============================================================================
; Detects test methods on testify suite receiver types.
;
; Example:
;   func (s *ExampleSuite) TestExample() {
;     s.Equal(1, 1)
;   }
;
; This query captures:
; - Method name (e.g., "TestExample")
; - Method declaration node
; - Only methods starting with "Test" or "Example"
;
; These methods become child tests under the suite namespace in the tree:
;   File -> TestXxxSuite (namespace) -> TestExample (test)
;
; NOTE: The receiver information is captured separately by namespace.scm.
; This query focuses only on identifying which methods are tests.
; ============================================================================
; query for test method
(method_declaration
  name: (field_identifier) @test.name
  (#match? @test.name "^(Test|Example)")
  (#not-match? @test.name "^TestMain$")) @test.definition
