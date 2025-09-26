; query for detecting receiver type and treat as Neotest namespace.

; func (suite *testSuite) TestSomething() { // @namespace_name
;  // test code
; }
(method_declaration
  receiver: (parameter_list
    (parameter_declaration
      type: (pointer_type
        (type_identifier) @namespace_name
      )
    )
  )
  name: (field_identifier) @test_function (#match? @test_function "^(Test|Example)") (#not-match? @test_function "^TestMain$")
) @namespace_definition