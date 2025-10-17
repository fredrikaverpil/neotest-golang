; ============================================================================
; RESPONSIBILITY: Testify suite identification (suite.Run with new())
; ============================================================================
; Detects testify suite test functions that use suite.Run() with new().
;
; This query identifies the pattern where a test function calls suite.Run()
; with a newly instantiated suite struct using new():
;
; Example:
;   func TestSuite(t *testing.T) {
;     suite.Run(t, new(testSuiteStruct))
;   }
;
; Captures:
; - @test_function: The test function name (e.g., "TestSuite")
; - @import_identifier: The suite import identifier (e.g., "suite")
; - @run_method: The Run method (always "Run")
; - @suite_struct: The suite struct type (e.g., "testSuiteStruct")
;
; Note: The %%s placeholder is replaced at runtime with the configured
; testify_import_identifier pattern (default: "^(suite)$").
;
; Used by lookup.lua to build the lookup table mapping receiver types
; to their corresponding suite test functions.
; ============================================================================
; query:
;
; func TestSuite(t *testing.T) {  // @test_function
;   suite.Run(t, new(testSuitestruct))  // @import_identifier, @run_method, @suite_receiver
; }
(function_declaration
  name: (identifier) @test_function
  (#match? @test_function "^Test")
  body: (block
    (statement_list
      (expression_statement
        (call_expression
          function: (selector_expression
            operand: (identifier) @import_identifier
            (#match? @import_identifier "%s")
            field: (field_identifier) @run_method
            (#match? @run_method "^Run$"))
          arguments: (argument_list
            (identifier)
            (call_expression
              arguments: (argument_list
                (type_identifier) @suite_struct))))))))
