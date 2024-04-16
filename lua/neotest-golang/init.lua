local lib = require("neotest.lib")
local async = require("neotest.async")
local neotest = {}

---@class neotest.Adapter
---@field name string
neotest.Adapter = { name = "neotest-golang" }

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param dir string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
function neotest.Adapter.root(dir)
  ---@type string | nil
  local cwd = lib.files.match_root_pattern("go.mod", "go.sum")(dir)
  if cwd == nil then
    return
  end
end

---Filter directories when searching for test files
---@async
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@param root string Root directory of project
---@return boolean
function neotest.Adapter.filter_dir(name, rel_path, root)
  local ignore_dirs = { ".git", "node_modules", ".venv", "venv" }
  for _, ignore in ipairs(ignore_dirs) do
    if name == ignore then
      return false
    end
  end
  return true
end

---@async
---@param file_path string
---@return boolean
function neotest.Adapter.is_test_file(file_path)
  ---@type boolean
  return vim.endswith(file_path, "_test.go")
end

---Given a file path, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function neotest.Adapter.discover_positions(file_path)
  local functions_and_methods = [[
    ;;query
    ((function_declaration
      name: (identifier) @test.name)
      (#match? @test.name "^(Test|Example)"))
      @test.definition

    (method_declaration
      name: (field_identifier) @test.name
      (#match? @test.name "^(Test|Example)")) @test.definition

    (call_expression
      function: (selector_expression
        field: (field_identifier) @test.method)
        (#match? @test.method "^Run$")
      arguments: (argument_list . (interpreted_string_literal) @test.name))
      @test.definition
  ]]

  local table_tests = [[
    ;; query for list table tests
        (block
          (short_var_declaration
            left: (expression_list
              (identifier) @test.cases)
            right: (expression_list
              (composite_literal
                (literal_value
                  (literal_element
                    (literal_value
                      (keyed_element
                        (literal_element
                          (identifier) @test.field.name)
                        (literal_element
                          (interpreted_string_literal) @test.name)))) @test.definition))))
          (for_statement
            (range_clause
              left: (expression_list
                (identifier) @test.case)
              right: (identifier) @test.cases1
                (#eq? @test.cases @test.cases1))
            body: (block
             (expression_statement
              (call_expression
                function: (selector_expression
                  field: (field_identifier) @test.method)
                  (#match? @test.method "^Run$")
                arguments: (argument_list
                  (selector_expression
                    operand: (identifier) @test.case1
                    (#eq? @test.case @test.case1)
                    field: (field_identifier) @test.field.name1
                    (#eq? @test.field.name @test.field.name1))))))))

    ;; query for map table tests 
      (block
          (short_var_declaration
            left: (expression_list
              (identifier) @test.cases)
            right: (expression_list
              (composite_literal
                (literal_value
                  (keyed_element
                  (literal_element
                      (interpreted_string_literal)  @test.name)
                    (literal_element
                      (literal_value)  @test.definition))))))
        (for_statement
           (range_clause
              left: (expression_list
                ((identifier) @test.key.name)
                ((identifier) @test.case))
              right: (identifier) @test.cases1
                (#eq? @test.cases @test.cases1))
            body: (block
               (expression_statement
                (call_expression
                  function: (selector_expression
                    field: (field_identifier) @test.method)
                    (#match? @test.method "^Run$")
                    arguments: (argument_list
                    ((identifier) @test.key.name1
                    (#eq? @test.key.name @test.key.name1))))))))
  ]]

  local query = functions_and_methods .. table_tests
  local opts = { nested_tests = true }

  ---@type neotest.Tree
  local positions = lib.treesitter.parse_positions(file_path, query, opts)

  -- TODO: populate dynamically generated tests using gotestsum

  return positions
end

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function neotest.Adapter.build_spec(args)
  local tree = args.tree

  if not tree then
    return
  end

  ---@type neotest.Position
  local pos = args.tree:data()

  -- require a test
  if pos.type ~= "test" then
    return
  end

  -- remove filename from path
  local folder_path = string.match(pos.path, "(.+)/")

  -- construct the test name
  local test_name = pos.id
  -- Remove the path before ::
  test_name = test_name:match("::(.*)$")
  -- Replace :: with /
  test_name = test_name:gsub("::", "/")
  -- Remove any quotes
  test_name = test_name:gsub('"', "")
  test_name = test_name:gsub("'", "")
  -- Replace any special characters with . so to avoid breaking regexp
  test_name = test_name:gsub("%[", ".")
  test_name = test_name:gsub("%]", ".")
  -- Replace any spaces with _
  test_name = test_name:gsub(" ", "_")

  local test_output_path = vim.fs.normalize(async.fn.tempname())

  local command = vim.tbl_flatten({
    -- TODO: extract arguments to configurable opts
    "go",
    "test",
    "-v",
    "-race",
    "-count=1",
    "-timeout=30s",
    "-coverprofile=" .. vim.fn.getcwd() .. "/coverage.out",
    "-json", -- TODO: enable json output and add parser
    folder_path,
    "-run",
    "^" .. test_name .. "$",
    "2>",
    test_output_path,
  })

  ---@type neotest.RunSpec
  local spec = {
    command = command,
    context = {
      test_output_path = test_output_path,
      id = pos.id,
    },
  }

  return spec
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function neotest.Adapter.results(spec, result, tree)
  -- debug
  -- print(vim.inspect(result.output))

  ---@type table
  local raw_output = async.fn.readfile(result.output)
  ---@type neotest.ResultStatus
  local result_status = "skipped"
  ---@type neotest.Error[]
  local errors = {}
  ---@type List<table>
  local jsonlines = Process_json(raw_output) -- TODO: pcall and error checking

  if result.code == 0 then
    result_status = "passed"
  else
    result_status = "failed"
  end

  -- TODO: this is just the start of parsing the jsonlines output
  local all_output = {}
  for _, line in ipairs(jsonlines) do
    if line.Action == "output" then
      table.insert(all_output, line.Output)
    end
    if line.Action == "fail" then
      if line.Test and type(line.Test) == "string" then
        local error = { message = "Failed test: " .. line.Test } -- TODO: add line number
        table.insert(errors, error)
        result_status = "failed"
      end
    end
  end

  -- write json_decoded to file
  local parsed_output_path = vim.fs.normalize(async.fn.tempname())
  async.fn.writefile(all_output, parsed_output_path)

  ---@type table<string, neotest.Result>
  local results = {}
  results[spec.context.id] = {
    status = result_status,
    output = parsed_output_path,
    -- short = "", -- TODO: add shortened output string
    errors = errors,
  }

  return results
end

--- Process JSON and return objects of interest
---@param raw_output table
---@return List, table
function Process_json(raw_output)
  ---@type table
  local jsonlines = {}

  for _, line in ipairs(raw_output) do
    if string.match(line, "^%s*{") then
      local json_data = vim.fn.json_decode(line)
      table.insert(jsonlines, json_data)
    else
      print("Warning, not a json line: " .. line)
    end
  end
  return jsonlines
end

return neotest.Adapter
