--- Lookup table for renaming Neotest namespaces (receiver type to testify suite function).

local query = require("neotest-golang.features.testify.query")
local options = require("neotest-golang.options")

local M = {}

-- TreeSitter query for identifying testify suites and their components.
-- Below, queries for the lookup between receiver and test suite.

M.package_query = [[
  ;; query:
  ;;
  ;; package main  // @package
  (package_clause
    (package_identifier) @package
  )
]]

M.suite_query = string.format(
  [[
  ;; query:
  ;;
  ;; func TestSuite(t *testing.T) {  // @test_function
  ;;   suite.Run(t, new(testSuitestruct))  // @import_identifier, @run_method, @suite_receiver
  ;; }
  (function_declaration
    name: (identifier) @test_function (#match? @test_function "^Test")
    body: (block
      (expression_statement
        (call_expression
          function: (selector_expression
            operand: (identifier) @import_identifier (#match? @import_identifier "%s")
            field: (field_identifier) @run_method (#match? @run_method "^Run$")
          )
          arguments: (argument_list
            (identifier)
            (call_expression
              arguments: (argument_list
                (type_identifier) @suite_struct
              )
            )
          )
        )
      )
    )
  )
]],
  options.get().testify_import_identifier
)

M.test_function_query = string.format(
  [[
  ;; query:
  ;;
  ;; func TestSuite(t *testing.T) {  // @test_function
  ;;   s := &testSuiteStruct{}  // @suite_struct
  ;;   suite.Run(t, s) // @import_identifier, @run_method
  ;; }
  (function_declaration 
    name: (identifier) @test_function (#match? @test_function "^Test")
    parameters: (parameter_list 
      (parameter_declaration 
        name: (identifier) 
        type: (pointer_type 
          (qualified_type 
            package: (package_identifier) 
            name: (type_identifier)
          )
        )
      )
    ) 
    body: (block 
      (short_var_declaration 
        left: (expression_list 
          (identifier)
        ) 
        right: (expression_list 
          (unary_expression 
            operand: (composite_literal 
              type: (type_identifier) @suite_struct 
              body: (literal_value)
            )
          )
        )
      ) 
      (expression_statement 
        (call_expression 
          function: (selector_expression 
            operand: (identifier) @import_identifier (#match? @import_identifier "%s")
            field: (field_identifier) @run_method (#match? @run_method "^Run$")
          )
          arguments: (argument_list 
            (identifier) 
            (identifier)
          )
        )
      )
    )
  )
]],
  options.get().testify_import_identifier
)

local function create_lookup_manager()
  local lookup_table = {}

  return {
    init = function(file_paths)
      for _, file_path in ipairs(file_paths) do
        lookup_table[file_path] = M.generate_data(file_path)
      end
      return lookup_table
    end,
    create = function(file_path)
      lookup_table[file_path] = M.generate_data(file_path)
      return lookup_table
    end,
    get = function()
      return lookup_table
    end,
    clear = function()
      lookup_table = {}
    end,
  }
end

-- Create an instance of the lookup manager
local lookup_manager = create_lookup_manager()

--- Public lookup functions.
M.initialize_lookup = lookup_manager.init
M.create_lookup = lookup_manager.create
M.get_lookup = lookup_manager.get
M.clear_lookup = lookup_manager.clear

--- Generate the lookup data for the given file.
--- @return table<string, table> The generated lookup table
function M.generate_data(file_path)
  local data = {}

  -- First pass: collect all data for the lookup table.
  local queries = M.package_query .. M.suite_query .. M.test_function_query
  local matches = query.run_query_on_file(file_path, queries)

  local package_name = matches.package
      and matches.package[1]
      and matches.package[1].text
    or "unknown"

  data = {
    package = package_name,
    replacements = {},
  }

  for i, struct in ipairs(matches.suite_struct or {}) do
    local func = matches.test_function[i]
    if func then
      data.replacements[struct.text] = func.text
    end
  end

  return data
end

return M
