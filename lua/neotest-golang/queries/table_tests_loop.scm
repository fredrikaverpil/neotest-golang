; query for list table tests (wrapped in loop)
(for_statement
  (range_clause
    left: (expression_list
      (identifier)
      (identifier) @test.case)
    right: (composite_literal
      type: (slice_type
        element: (struct_type
          (field_declaration_list
            (field_declaration
              name: (field_identifier)
              type: (type_identifier)))))
      body: (literal_value
        (literal_element
          (literal_value
            (keyed_element
              (literal_element
                (identifier)) @test.field.name
              (literal_element
                (interpreted_string_literal) @test.name))) @test.definition))))
  body: (block
    (statement_list
      (expression_statement
        (call_expression
          function: (selector_expression
            operand: (identifier)
            field: (field_identifier))
          arguments: (argument_list
            (selector_expression
              operand: (identifier)
              field: (field_identifier) @test.field.name1)
            (#eq? @test.field.name @test.field.name1)))))))
