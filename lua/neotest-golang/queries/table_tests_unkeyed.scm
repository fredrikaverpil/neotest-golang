;; query for table tests with inline structs (not keyed)
(block
  (statement_list
    (short_var_declaration
      left: (expression_list (identifier) @test.cases
      )
      right: (expression_list
        (composite_literal
          body: (literal_value
            (literal_element
              (literal_value
                (literal_element
                  (interpreted_string_literal) @test.name
                )
                (literal_element)
              ) @test.definition
            )
          )
        )
      )
    )
    (for_statement
      (range_clause
        left: (expression_list
          (
            (identifier) @test.key.name
          )
          (
            (identifier) @test.case
          )
        )
        right: (identifier) @test.cases1 (#eq? @test.cases @test.cases1)
      )
      body: (block
        (statement_list
          (expression_statement
            (call_expression
              function: (selector_expression
                operand: (identifier) @test.operand (#match? @test.operand "^[t]$")
                field: (field_identifier) @test.method (#match? @test.method "^Run$")
              )
              arguments: (argument_list
                (selector_expression
                  operand: (identifier) @test.case1 (#eq? @test.case @test.case1)
                )
              )
            )
          )
        )
      )
    )
  )
)