local lib = require("neotest.lib")
local async = require("neotest.async")

local convert = require("neotest-golang.convert")

local M = {}

---@class neotest.Adapter
---@field name string
M.Adapter = { name = "neotest-golang" }

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param dir string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
function M.Adapter.root(dir)
  -- Since neotest-golang is setting the cwd prior to running tests or debugging
  -- we can use the cwd as-is and treat it as the root.
  return dir
end

---Filter directories when searching for test files
---@async
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@param root string Root directory of project
---@return boolean
function M.Adapter.filter_dir(name, rel_path, root)
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
function M.Adapter.is_test_file(file_path)
  ---@type boolean
  return vim.endswith(file_path, "_test.go")
end

---Given a file path, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function M.Adapter.discover_positions(file_path)
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

  return positions
end

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function M.Adapter.build_spec(args)
  ---@type neotest.Tree
  local tree = args.tree
  ---@type neotest.Position
  local pos = args.tree:data()

  if not tree then
    vim.notify("NOT A TREE!")
    return
  end

  if pos.type == "dir" and pos.path == vim.fn.getcwd() then
    -- Test suite

    return -- delegate test execution to per-test execution

    -- NOTE: could potentially run 'go test' on the whole directory, to make
    -- tests go a lot faster, but would come with the added complexity of
    -- having to traverse the node tree manually and set statuses accordingly.
    -- I'm not sure it's worth it...
  elseif pos.type == "dir" then
    -- Sub-directory

    return -- delegate test execution to per-test execution

    -- NOTE: could potentially run 'go test' on the whole file, to make
    -- tests go a lot faster, but would come with the added complexity of
    -- having to traverse the node tree manually and set statuses accordingly.
    -- I'm not sure it's worth it...
    --
    -- ---@type string
    -- local relative_test_folderpath = vim.fn.fnamemodify(pos.path, ":~:.")
    -- ---@type string
    -- local relative_test_folderpath_go = "./"
    --   .. relative_test_folderpath
    --   .. "/..."
  elseif pos.type == "file" then
    -- Single file

    if M.table_is_empty(tree:children()) then
      -- No tests present in file
      ---@type neotest.RunSpec
      local run_spec = {
        command = { "echo", "No tests found in file" },
        context = {
          id = pos.id,
          skip = true,
        },
      }
      return run_spec
    else
      -- Go does not run tests based on files, but on the package name. If Go
      -- is given a filepath, in which tests resides, it also needs to have all
      -- other filepaths that might be related passed as arguments to be able
      -- to compile. This approach is too brittle, and therefore this mode is not
      -- supported. Instead, the tests of a file are run as if pos.typ == "test".

      return -- delegate test execution to per-test execution
    end
  elseif pos.type == "test" then
    -- Single test
    return M.build_single_test_runspec(pos, args.strategy)
  else
    vim.notify("ERROR: WHAT IS THIS ???: " .. pos.type)
    return
  end
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function M.Adapter.results(spec, result, tree)
  if spec.context.skip then
    ---@type table<string, neotest.Result>
    local results = {}
    results[spec.context.id] = {
      ---@type neotest.ResultStatus
      status = "skipped",
    }
    return results
  end

  ---@type neotest.ResultStatus
  local result_status = "skipped"
  if result.code == 0 then
    result_status = "passed"
  else
    result_status = "failed"
  end

  ---@type table
  local raw_output = async.fn.readfile(result.output)

  ---@type string
  local test_filepath = spec.context.test_filepath
  local test_filename = vim.fn.fnamemodify(test_filepath, ":t")
  ---@type List
  local test_result = {}
  ---@type neotest.Error[]
  local errors = {}
  ---@type List<table>
  local jsonlines = M.process_json(raw_output)

  local panic_detected = false

  for _, line in ipairs(jsonlines) do
    if line.Action == "output" and line.Output ~= nil then
      -- record output, prints to output panel
      table.insert(test_result, line.Output)

      -- register panic found
      local panic_match = string.match(line.Output, "panic:")
      if panic_match ~= nil then
        panic_detected = true
      end
    end

    if result.code ~= 0 and line.Output ~= nil then
      -- record an error
      ---@type string
      local matched_line_number =
        string.match(line.Output, test_filename .. ":(%d+)")

      if matched_line_number ~= nil then
        -- attempt to parse the line number...
        ---@type number | nil
        local line_number = tonumber(matched_line_number)

        if line_number ~= nil then
          -- log the error along with its line number (for diagnostics)
          ---@type neotest.Error
          local error = {
            message = line.Output,
            line = line_number - 1, -- neovim lines are 0-indexed
          }
          table.insert(errors, error)
        end
      end
    end
  end

  if panic_detected then
    -- remove all line numbers, as neotest diagnostics will crash if they are present
    local new_errors = {}
    for _, error in ipairs(errors) do
      local new_error = { message = error.message }
      table.insert(new_errors, new_error)
    end
    errors = new_errors
  end

  -- write json_decoded to file
  local parsed_output_path = vim.fs.normalize(async.fn.tempname())
  async.fn.writefile(test_result, parsed_output_path)

  ---@type table<string, neotest.Result>
  local results = {}
  results[spec.context.id] = {
    status = result_status,
    output = parsed_output_path,
    errors = errors,
  }

  -- FIXME: once output is parsed, erase file contents, so to avoid JSON in
  -- output panel. This is a workaround for now, only because of
  -- https://github.com/nvim-neotest/neotest/issues/391
  vim.fn.writefile({ "" }, result.output)

  return results
end

--- Build runspec for a single test
---@param pos neotest.Position
---@param strategy string
---@return neotest.RunSpec
function M.build_single_test_runspec(pos, strategy)
  ---@type string
  local test_name = convert.to_gotest_test_name(pos.id)
  ---@type string
  local test_folder_absolute_path = string.match(pos.path, "(.+)/")

  local gotest = {
    "go",
    "test",
    "-json",
  }

  ---@type table
  local go_test_args = {
    test_folder_absolute_path,
    "-run",
    "^" .. test_name .. "$",
  }

  local combined_args =
    vim.list_extend(vim.deepcopy(M.Adapter._go_test_args), go_test_args)
  local gotest_command = vim.list_extend(vim.deepcopy(gotest), combined_args)

  ---@type neotest.RunSpec
  local run_spec = {
    command = gotest_command,
    cwd = test_folder_absolute_path,
    context = {
      id = pos.id,
      test_filepath = pos.path,
    },
  }

  -- set up for debugging of test
  if strategy == "dap" then
    run_spec.strategy = M.get_dap_config(test_name)
    run_spec.context.skip = true -- do not attempt to parse test output

    -- nvim-dap and nvim-dap-go cwd
    if M.Adapter._dap_go_enabled then
      local dap_go_opts = M.Adapter._dap_go_opts or {}
      local dap_go_opts_original = vim.deepcopy(dap_go_opts)
      if dap_go_opts.delve == nil then
        dap_go_opts.delve = {}
      end
      dap_go_opts.delve.cwd = test_folder_absolute_path
      require("dap-go").setup(dap_go_opts)

      -- reset nvim-dap-go (and cwd) after debugging with nvim-dap
      require("dap").listeners.after.event_terminated["neotest-golang-debug"] = function()
        require("dap-go").setup(dap_go_opts_original)
      end
    end
  end

  return run_spec
end

---@param test_name string
---@return table | nil
function M.get_dap_config(test_name)
  -- :help dap-configuration
  local dap_config = {
    type = "go",
    name = "Neotest-golang",
    request = "launch",
    mode = "test",
    program = "${fileDirname}",
    args = { "-test.run", "^" .. test_name .. "$" },
  }

  return dap_config
end

function M.table_is_empty(t)
  return next(t) == nil
end

--- Process JSON and return objects of interest
---@param raw_output table
---@return table
function M.process_json(raw_output)
  ---@type table
  local jsonlines = {}

  for _, line in ipairs(raw_output) do
    if string.match(line, "^%s*{") then
      local json_data = vim.fn.json_decode(line)
      table.insert(jsonlines, json_data)
    else
      -- TODO: log these to file instead...
      -- vim.notify("Warning, not a json line: " .. line)
    end
  end
  return jsonlines
end

---@type List
M.Adapter._go_test_args = {
  "-v",
  "-race",
  "-count=1",
  "-timeout=60s",
}

-- nvim-dap-go config
M.Adapter._dap_go_enabled = false
M.Adapter._dap_go_opts = {}

setmetatable(M.Adapter, {
  __call = function(_, opts)
    return M.Adapter.setup(opts)
  end,
})

M.Adapter.setup = function(opts)
  opts = opts or {}
  if opts.args or opts.dap_go_args then
    -- temporary warning
    vim.notify(
      "Please update your config, the arguments/opts have changed for neotest-golang.",
      vim.log.levels.WARN
    )
  end
  if opts.go_test_args then
    if opts.go_test_args then
      M.Adapter._go_test_args = opts.go_test_args
    end
    if opts.dap_go_enabled then
      M.Adapter._dap_go_enabled = opts.dap_go_enabled
      if opts.dap_go_opts then
        M.Adapter._dap_go_opts = opts.dap_go_opts
      end
    end
  end

  return M.Adapter
end

return M.Adapter
