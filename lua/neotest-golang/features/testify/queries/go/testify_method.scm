; ============================================================================
; RESPONSIBILITY: Testify suite receiver type detection
; ============================================================================
; Detects testify suite test methods and their receiver types for method-to-suite
; mapping needed for the final structure implementation.
;
; In testify suites, test methods are defined on a receiver type:
;   type ExampleSuite struct {
;     suite.Suite
;   }
;   func (s *ExampleSuite) TestSomething(t *testing.T) { ... }
;
; This query captures:
; - The method name as @test.name
; - The entire method declaration as @test.definition
; - The receiver type identifier (e.g., "ExampleSuite") as @testify_suite_struct
; - Only methods starting with "Test" or "Example"
;
; Example with capture annotation:
;   func (suite *testSuite) TestSomething() { // @testify_suite_struct captures "testSuite"
;                                             // @test.name captures "TestSomething"
;     // test code                            // @test.definition captures the entire function
;   }
;
; @test.name and @test.definition are used by neotest to detect the test
; @testify_suite_struct is used by lookup.lua to build a mapping between receiver types
; and their suite functions, which tree_modification.lua uses to rename test IDs.
; ============================================================================
(method_declaration
  receiver: (parameter_list
    (parameter_declaration
      type: (pointer_type
        (type_identifier) @testify_suite_struct)))
  name: (field_identifier) @test.name
  (#match? @test.name "^(Test|Example)")
  (#not-match? @test.name "^TestMain$")) @test.definition
