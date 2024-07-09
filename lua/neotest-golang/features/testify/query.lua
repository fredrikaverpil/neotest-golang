local M = {}

M.namespace_query = [[
  ; query for receiver method, to be used as test suite namespace initially (will be replaced later).
   (method_declaration
    receiver: (parameter_list
      (parameter_declaration
        ; name: (identifier)
        type: (pointer_type
          (type_identifier) @namespace.name )))) @namespace.definition
  ]]

return M
