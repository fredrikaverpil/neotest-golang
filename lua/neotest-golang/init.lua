local lib = require("neotest.lib")
local async = require("neotest.async")
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
  -- if M.find_go_files(vim.fn.getcwd(), M.Adapter._search_depth) then
  --   return dir
  -- end

  print("Got this dir:")
  print(dir)
  return dir

  -- print("ROOT LOOKING")
  -- local common_dir = M.find_common_path(dir, M.Adapter._search_depth)
  --
  -- print("ultimately:")
  -- print(common_dir)
  -- return common_dir
end

--- Find the directory which contains all the go.mod files of the project.
---@param dir string @Project directory to start scan from.
---@param max_depth number @Maximum depth to search for go.mod files.
---@return string | nil @Absolute path to the directory under which all go.mod files are found.
function M.find_common_path(dir, max_depth)
  local scan = require("plenary.scandir")
  local scan_opts = {
    hidden = false,
    depth = max_depth,
    search_pattern = "go.mod",
  }
  local paths = scan.scan_dir(dir, scan_opts)
  print(vim.inspect(paths))

  -- if multiple paths are found, find the common directory
  local common_path = M.common_path(paths)

  print("ok back here agaiin")

  -- if path is file, return parent directory
  local Path = require("plenary.path")
  local p = Path:new(common_path)

  print("does this break or something?")
  print(vim.inspect(p))

  local final = nil

  if p:is_file() then
    print("is file")
    final = p:parent():absolute()
  elseif p:is_dir() then
    print("is dir")
    final = p:absolute()
  end

  -- remove last character if it is an os separator
  local lastchar = final:sub(-1)
  if lastchar == "/" or lastchar == "\\" then
    final = final:sub(1, -2)
  end

  return final
end

function M.common_path(paths)
  if #paths == 0 then
    return ""
  end
  table.sort(paths)
  local first_path = paths[1]
  local last_path = paths[#paths]
  local i = 1
  while
    i <= #first_path
    and i <= #last_path
    and first_path:sub(i, i) == last_path:sub(i, i)
  do
    i = i + 1
  end
  local p = first_path:sub(1, i - 1)
  print("COMMON!!")
  print(p)
  return p
end

---Filter directories when searching for test files
---@async
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@param root string Root directory of project
---@return boolean
function M.Adapter.filter_dir(name, rel_path, root)
  print("FILTER")
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

      if matched_line_number == nil or panic_detected then
        -- log the error without a line number
        ---@type neotest.Error
        local error = { message = line.Output }
        table.insert(errors, error)
      else
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

---Find the project root directory given a current directory to work from
---@param root_path string @Root path of project
---@param search_depth number @Maximum depth to search for go.mod or go.sum
---@return boolean @True if go.mod or go.sum is found, false otherwise
function M.find_go_files(root_path, search_depth)
  local stack = { { root_path, 0 } }
  while #stack > 0 do
    local top = table.remove(stack)
    local dir = top[1]
    local level = top[2]
    if level > search_depth then
      return false
    end
    local files = vim.fn.globpath(dir, "*", true, true)
    for _, file in ipairs(files) do
      if vim.fn.isdirectory(file) == 1 then
        table.insert(stack, { file, level + 1 })
      elseif
        vim.fn.fnamemodify(file, ":t") == "go.mod"
        or vim.fn.fnamemodify(file, ":t") == "go.sum"
      then
        return true
      end
    end
  end
  return false
end

--- Build runspec for a single test
---@param pos neotest.Position
---@param strategy string
---@return neotest.RunSpec
function M.build_single_test_runspec(pos, strategy)
  ---@type string
  local test_name = M.test_name_from_pos_id(pos.id)
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

---@param pos_id string
---@return string
function M.test_name_from_pos_id(pos_id)
  -- construct the test name
  local test_name = pos_id
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
  test_name = test_name:gsub("%(", ".")
  test_name = test_name:gsub("%)", ".")
  -- Replace any spaces with _
  test_name = test_name:gsub(" ", "_")

  return test_name
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

-- Adapter options
---@type List
M.Adapter._go_test_args = {
  "-v",
  "-race",
  "-count=1",
  "-timeout=60s",
}
M.Adapter._dap_go_enabled = false
M.Adapter._dap_go_opts = {}
M.Adapter._search_depth = 4

setmetatable(M.Adapter, {
  __call = function(_, opts)
    return M.Adapter.setup(opts)
  end,
})

--- Setup the adapter
---@param opts table
---@return table
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
    M.Adapter._go_test_args = opts.go_test_args
  end
  if opts.dap_go_enabled then
    M.Adapter._dap_go_enabled = opts.dap_go_enabled
    if opts.dap_go_opts then
      M.Adapter._dap_go_opts = opts.dap_go_opts
    end
  end
  if opts.search_depth then
    M.Adapter._search_depth = opts.search_depth
  end

  return M.Adapter
end

return M.Adapter
