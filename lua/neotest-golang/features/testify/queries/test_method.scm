; query for test method
(method_declaration
  name: (field_identifier) @test.name
  (#match? @test.name "^(Test|Example)")
  (#not-match? @test.name "^TestMain$")) @test.definition

