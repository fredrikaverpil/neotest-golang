--- Query for detecting receiver type and treat as Neotest namespace.

local M = {}

M.query = [[
  ; query for detecting receiver type and treat as Neotest namespace.

  ; func (suite *testSuite) TestSomething() { // @namespace.name
  ;  // test code
  ; }
   (method_declaration
    receiver: (parameter_list
      (parameter_declaration
        ; name: (identifier)
        type: (pointer_type
          (type_identifier) @namespace.name )))) @namespace.definition
    name: (field_identifier) @test_function (#match? @test_function "^Test")
  ]]

return M
