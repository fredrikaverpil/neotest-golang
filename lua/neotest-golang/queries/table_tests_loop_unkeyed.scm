;; query for table tests with inline structs (not keyed, wrapped in loop)
(for_statement
  (range_clause
    left: (expression_list
      (identifier)
      (identifier) @test.case
    )
    right: (composite_literal
      type: (slice_type
        element: (struct_type
          (field_declaration_list
            (field_declaration
              name: (field_identifier) @test.field.name
              type: (type_identifier) @field.type (#eq? @field.type "string")
            )
          )
        )
      )
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
            field: (field_identifier) @test.field.name1 (#eq? @test.field.name @test.field.name1)
          )
        )
      )
    )
  )
)
)