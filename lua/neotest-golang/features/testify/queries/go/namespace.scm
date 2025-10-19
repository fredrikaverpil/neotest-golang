; ============================================================================
; RESPONSIBILITY: Testify suite receiver type detection
; ============================================================================
; Detects receiver types in testify suite test methods for method-to-suite
; mapping in the flat structure implementation.
;
; In testify suites, test methods are defined on a receiver type:
;   type ExampleSuite struct {
;     suite.Suite
;   }
;   func (s *ExampleSuite) TestSomething(t *testing.T) { ... }
;
; This query captures:
; - The receiver type identifier (e.g., "ExampleSuite") as @namespace_name
; - The method declaration itself
; - Only methods starting with "Test" or "Example"
;
; Example with capture annotation:
;   func (suite *testSuite) TestSomething() { // @namespace_name captures "testSuite"
;     // test code
;   }
;
; The flat structure approach:
;   File -> TestSuiteName/MethodName (no namespace nodes)
;
; This data is used by lookup.lua to build a mapping between receiver types
; and their suite functions, which tree_modification.lua uses to rename test IDs.
; ============================================================================
(method_declaration
  receiver: (parameter_list
    (parameter_declaration
      type: (pointer_type
        (type_identifier) @namespace_name)))
  name: (field_identifier) @test_function
  (#match? @test_function "^(Test|Example)")
  (#not-match? @test_function "^TestMain$")) @namespace_definition
