; query for test function
((function_declaration
  name: (identifier) @test.name)
  (#match? @test.name "^(Test|Example)")
  (#not-match? @test.name "^TestMain$")) @test.definition

; query for subtest, like t.Run(), s.Run(), suite.Run()
(call_expression
  function: (selector_expression
    operand: (identifier) @test.operand
    (#match? @test.operand "^(t|s|suite)$")
    field: (field_identifier) @test.method)
  (#match? @test.method "^Run$")
  arguments: (argument_list
    .
    (interpreted_string_literal) @test.name)) @test.definition
