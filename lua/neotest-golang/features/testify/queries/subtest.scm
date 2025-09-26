; query for subtest, like s.Run(), suite.Run()
; Note: The operand pattern is dynamically inserted based on testify_operand option
(call_expression
  function: (selector_expression
    operand: (identifier) @test.operand (#match? @test.operand "%s")
    field: (field_identifier) @test.method (#match? @test.method "^Run$")
  )
  arguments: (argument_list
    . (interpreted_string_literal) @test.name
  )
) @test.definition