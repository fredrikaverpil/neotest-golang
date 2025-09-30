; query for list table tests
(block
  (statement_list
    (short_var_declaration
      left: (expression_list
        (identifier) @test.cases)
      right: (expression_list
        (composite_literal
          (literal_value
            (literal_element
              (literal_value
                (keyed_element
                  (literal_element
                    (identifier) @test.field.name)
                  (literal_element
                    (interpreted_string_literal) @test.name)))) @test.definition))))
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
                (#match? @test.operand "^[t]$")
                field: (field_identifier) @test.method
                (#match? @test.method "^Run$"))
              arguments: (argument_list
                (selector_expression
                  operand: (identifier) @test.case1
                  (#eq? @test.case @test.case1)
                  field: (field_identifier) @test.field.name1
                  (#eq? @test.field.name @test.field.name1))))))))))
