; ============================================================================
; RESPONSIBILITY: Testify suite identification (suite.Run with variable)
; ============================================================================
; Detects testify suite test functions that use suite.Run() with a variable.
;
; This query identifies the pattern where a test function creates a suite
; struct variable and then passes it to suite.Run():
;
; Example:
;   func TestSuite(t *testing.T) {
;     s := &testSuiteStruct{}
;     suite.Run(t, s)
;   }
;
; Captures:
; - @test_function: The test function name (e.g., "TestSuite")
; - @suite_struct: The suite struct type (e.g., "testSuiteStruct")
; - @import_identifier: The suite import identifier (e.g., "suite")
; - @run_method: The Run method (always "Run")
;
; Note: The %%s placeholder is replaced at runtime with the configured
; testify_import_identifier pattern (default: "^(suite)$").
;
; This is an alternative to the suite.scm query, which handles the
; suite.Run(t, new(Struct)) pattern. This query handles the case where
; the suite struct is created in a variable first.
;
; Used by lookup.lua to build the lookup table mapping receiver types
; to their corresponding suite test functions.
; ============================================================================
; query:
;
; func TestSuite(t *testing.T) {  // @test_function
;   s := &testSuiteStruct{}  // @suite_struct
;   suite.Run(t, s) // @import_identifier, @run_method
; }
(function_declaration
  name: (identifier) @test_function
  (#match? @test_function "^Test")
  parameters: (parameter_list
    (parameter_declaration
      name: (identifier)
      type: (pointer_type
        (qualified_type
          package: (package_identifier)
          name: (type_identifier)))))
  body: (block
    (statement_list
      (short_var_declaration
        left: (expression_list
          (identifier))
        right: (expression_list
          (unary_expression
            operand: (composite_literal
              type: (type_identifier) @suite_struct
              body: (literal_value)))))
      (expression_statement
        (call_expression
          function: (selector_expression
            operand: (identifier) @import_identifier
            (#match? @import_identifier "%s")
            field: (field_identifier) @run_method
            (#match? @run_method "^Run$"))
          arguments: (argument_list
            (identifier)
            (identifier)))))))
