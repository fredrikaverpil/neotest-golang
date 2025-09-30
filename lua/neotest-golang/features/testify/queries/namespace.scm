; ============================================================================
; RESPONSIBILITY: Testify suite receiver types (used as namespaces)
; ============================================================================
; Detects receiver types in testify suite test methods to create namespaces.
;
; In testify suites, test methods are defined on a receiver type:
;   type ExampleSuite struct {
;     suite.Suite
;   }
;   func (s *ExampleSuite) TestSomething(t *testing.T) { ... }
;
; This query captures:
; - The receiver type identifier (e.g., "ExampleSuite")
; - The method declaration itself
; - Only methods starting with "Test" or "Example"
;
; The receiver type becomes a Neotest namespace, allowing the tree structure:
;   File -> TestXxxSuite (namespace) -> TestMethod (test)
;
; This is later processed by tree_modification.lua to map receiver types
; to their corresponding suite initialization functions (TestXxxSuite).
; ============================================================================

; query for detecting receiver type and treat as Neotest namespace.
; func (suite *testSuite) TestSomething() { // @namespace_name
;  // test code
; }
(method_declaration
  receiver: (parameter_list
    (parameter_declaration
      type: (pointer_type
        (type_identifier) @namespace_name)))
  name: (field_identifier) @test_function
  (#match? @test_function "^(Test|Example)")
  (#not-match? @test_function "^TestMain$")) @namespace_definition

