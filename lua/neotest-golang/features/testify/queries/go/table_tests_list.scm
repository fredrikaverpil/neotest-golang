; ============================================================================
; RESPONSIBILITY: Table-driven tests with named slice variable and keyed fields
; ============================================================================
; Detects table tests inside testify methods where test cases are defined in a
; named variable with keyed struct fields (e.g., {name: "test1"}).
;
; Example with captures:
;   type ExampleSuite struct { suite.Suite }
;   
;   func (s *ExampleSuite) TestExample() {
;   	tests := []struct {
;   		name  string
;   		input int
;   		want  int
;   	}{
;   		{                       // @test.definition captures table test block
;   			name:  "test case", // @test.name captures "test case"
;   			input: 10,
;   			want:  20,
;   		},
;   	}
;   	for _, tt := range tests {
;   		s.Run(tt.name, func() {
;   		}
;   	}
;   }
;
; Since @test.definition range is strictly a subset of the test range captured
; by testify_method.scm, neotest will nest captured table tests from this
; query correctly under their parent test.
; ============================================================================

(method_declaration
  receiver: (parameter_list
    (parameter_declaration
      name: (identifier) @receiver_name
      type: (pointer_type
        (type_identifier))))
  name: (field_identifier) @test_func
  (#match? @test_func "^(Test|Example)")
  (#not-match? @test_func "^TestMain$")
  body: (block
    (statement_list
      [
        (var_declaration
          (var_spec
            name: (identifier) @test.cases
            value: (expression_list
            (composite_literal
              body: (literal_value
                (literal_element
                  (literal_value
                    (keyed_element
                      key: (literal_element
                        (identifier) @test.field.name)
                      value: (literal_element
                        (interpreted_string_literal
                          (interpreted_string_literal_content) @test.name))))) @test.definition)))))
        (short_var_declaration
          left: (expression_list
            (identifier) @test.cases)
          right: (expression_list
            (composite_literal
              body: (literal_value
                (literal_element
                  (literal_value
                    (keyed_element
                      key: (literal_element
                        (identifier) @test.field.name)
                      value: (literal_element
                        (interpreted_string_literal
                          (interpreted_string_literal_content) @test.name))))) @test.definition))))
      ]
      (for_statement
        (range_clause
          left: (expression_list
            (identifier) @test.case)
          right: (identifier) @test.cases1
          (#eq? @test.cases @test.cases1))
        body: (block
          (statement_list
            (expression_statement
              (call_expression
                function: (selector_expression
                  operand: (identifier) @test.operand
                  (#eq? @test.operand @receiver_name)
                  field: (field_identifier) @test.method
                  (#match? @test.method "^Run$"))
                arguments: (argument_list
                  (selector_expression
                    operand: (identifier) @test.case1
                    (#eq? @test.case @test.case1)
                    field: (field_identifier) @test.field.name1
                    (#eq? @test.field.name @test.field.name1)))))))))))
