; ============================================================================
; RESPONSIBILITY: Testify suite test methods
; ============================================================================
; Detects test methods defined on testify suite receiver types. These are
; methods that belong to a suite struct and run as individual tests.
;
; Pattern structure:
; 1. Method with receiver: func (s *SuiteType) MethodName() { ... }
; 2. Method name starts with "Test" or "Example"
; 3. Excludes TestMain
;
; Example with captures:
;   type ExampleSuite struct { suite.Suite }
;
;   func (s *ExampleSuite) TestExample() {  // @test.name = "TestExample"
;     s.Equal(1, 1)                          // @test.definition = entire method
;   }
;
; What gets captured:
; - @test.name = The method name (e.g., "TestExample")
; - @test.definition = The entire method declaration
;
; Tree structure: File -> TestXxxSuite (namespace) -> TestExample (test)
; The receiver type (namespace) is captured by namespace.scm, this query only
; identifies which methods are tests.
; ============================================================================
(method_declaration
  name: (field_identifier) @test.name
  (#match? @test.name "^(Test|Example)")
  (#not-match? @test.name "^TestMain$")) @test.definition
