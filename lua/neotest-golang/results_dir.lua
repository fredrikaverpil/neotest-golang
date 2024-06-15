local async = require("neotest.async")

local convert = require("neotest-golang.convert")
local json = require("neotest-golang.json")
local utils = require("neotest-golang.utils")

--- @class InternalResult
--- @field status neotest.ResultStatus
--- @field output? string[] Go test output.
--- @field short? string Shortened output string
--- @field errors? neotest.Error[]
--- @field neotest_node_data neotest.Position
--- @field go_test_data GoTestData
--- @field duplicate_test_detected boolean

--- @class GoTestData
--- @field name string
--- @field package string

local M = {}

--- Process the results from the test command executing all tests in a
--- directory.
--- @param spec neotest.RunSpec
--- @param result neotest.StrategyResult
--- @param tree neotest.Tree
function M.results(spec, result, tree)
  --- The raw output from the 'go test -json' command.
  --- @type table
  local raw_output = async.fn.readfile(result.output)

  --- The 'go test' JSON output, converted into a lua table.
  --- @type table
  local gotest_output = json.process_json(raw_output)

  --- Internal data structure to store test results.
  --- @type table<string, InternalResult>
  local d = M.aggregate_data(tree, gotest_output)

  M.show_warnings(d)

  local neotest_results = M.to_neotest_results(spec, result, d, gotest_output)

  -- FIXME: once output is parsed, erase file contents, so to avoid JSON in
  -- output panel. This is a workaround for now, only because of
  -- https://github.com/nvim-neotest/neotest/issues/391
  vim.fn.writefile({ "" }, result.output)

  -- DEBUG: enable the following to see the collected data
  -- vim.notify(vim.inspect(internal_results), vim.log.levels.DEBUG)

  return neotest_results
end

--- Aggregate neotest data and 'go test' output data.
--- @param tree neotest.Tree
--- @param gotest_output table
--- @return table<string, InternalResult>
function M.aggregate_data(tree, gotest_output)
  local d = M.gather_neotest_data_and_set_defaults(tree)
  d = M.decorate_with_go_package_and_test_name(d, gotest_output)
  d = M.decorate_with_go_test_results(d, gotest_output)
  return d
end

--- Generate the internal data which will be used by neotest-golang before.
--- handing over the final results onto Neotest.
--- @param tree neotest.Tree
--- @return table<string, InternalResult>
function M.gather_neotest_data_and_set_defaults(tree)
  --- Internal data structure to store test results.
  --- @type table<string, InternalResult>
  local d = {}

  --- Table storing the name of the test (position.id) and the number of times
  --- it was found in the tree.
  --- @type table<string, number>
  local dupes = {}

  for _, node in tree:iter_nodes() do
    --- @type neotest.Position
    local pos = node:data()

    if pos.type == "test" then
      d[pos.id] = {
        status = "skipped", -- default
        output = {}, -- default -- TODO: move into go_test_data
        errors = {}, -- default -- TODO: move into go_test_data
        neotest_node_data = pos, -- TODO: rename to neotest_position_data
        go_test_data = {
          name = "", -- default
          package = "", -- default
        }, -- default
        duplicate_test_detected = false, -- default
      }

      -- detect duplicate test names
      if dupes[pos.id] == nil then
        dupes[pos.id] = 1
      else
        dupes[pos.id] = dupes[pos.id] + 1
        d[pos.id].duplicate_test_detected = true
      end
    end
  end
  return d
end

--- Decorate the internal results with go package and test name.
--- This is an important step to associate the test results with the tree nodes
--- as the 'go test' JSON output contains keys 'Package' and 'Test'.
--- @param d table<string, InternalResult>
--- @param gotest_output table
--- @return table<string, InternalResult>
function M.decorate_with_go_package_and_test_name(d, gotest_output)
  for pos_id in pairs(d) do
    for _, line in ipairs(gotest_output) do
      if line.Action == "run" and line.Test ~= nil then
        local folderpath =
          vim.fn.fnamemodify(d[pos_id].neotest_node_data.path, ":h")
        local match = nil
        local common_path = utils.find_common_path(line.Package, folderpath)

        if common_path ~= "" then
          local tweaked_neotest_node_id = pos_id:gsub(" ", "_")
          tweaked_neotest_node_id = tweaked_neotest_node_id:gsub('"', "")
          tweaked_neotest_node_id = tweaked_neotest_node_id:gsub("::", "/")

          local combined_pattern = convert.to_lua_pattern(common_path)
            .. "/(.-)/"
            .. convert.to_lua_pattern(line.Test)
            .. "$"

          match = tweaked_neotest_node_id:match(combined_pattern)
        end
        if match ~= nil then
          d[pos_id].go_test_data = {
            package = line.Package,
            name = line.Test,
          }
          break -- avoid iterating over the rest of the 'go test' output  lines
        end
      end
    end
  end

  return d
end

--- Decorate the internal results with data from the 'go test' output.
--- @param d table<string, InternalResult>
--- @param gotest_output table
--- @return table<string, InternalResult>
function M.decorate_with_go_test_results(d, gotest_output)
  for pos_id in pairs(d) do
    for _, line in ipairs(gotest_output) do
      if
        d[pos_id].go_test_data.package == line.Package
        and d[pos_id].go_test_data.name == line.Test
      then
        -- record test status
        if line.Action == "pass" then
          d[pos_id].status = "passed"
        elseif line.Action == "fail" then
          d[pos_id].status = "failed"
        elseif line.Action == "output" then
          -- append line.Output to output field
          d[pos_id].output = vim.list_extend(d[pos_id].output, { line.Output })

          -- determine test filename
          local test_filename = "_test.go" -- approximate test filename
          if d[pos_id].neotest_node_data ~= nil then
            -- node data is available, get the exact test filename
            local test_filepath = d[pos_id].neotest_node_data.path
            test_filename = vim.fn.fnamemodify(test_filepath, ":t")
          end

          -- search for error message and line number
          local matched_line_number =
            string.match(line.Output, test_filename .. ":(%d+):")
          if matched_line_number ~= nil then
            local line_number = tonumber(matched_line_number)
            local message =
              string.match(line.Output, test_filename .. ":%d+: (.*)")
            if line_number ~= nil and message ~= nil then
              table.insert(d[pos_id].errors, {
                line = line_number - 1, -- neovim lines are 0-indexed
                message = message,
              })
            end
          end
        end
      end
    end
  end
  return d
end

--- Show warnings.
--- @param d table<string, InternalResult>
--- @return nil
function M.show_warnings(d)
  -- warn if Go package/test is missing from tree node.
  -- TODO: make configurable to skip this or use different log level?
  for pos_id in pairs(d) do
    if d[pos_id].go_test_data.name == "" then
      vim.notify(
        "Unable to associate go package/test with neotest tree node: " .. pos_id,
        vim.log.levels.WARN
      )
    end
  end

  -- TODO: warn (or debug log) if Go test was detected, but is not found in the AST/treesitter tree.

  -- warn about duplicate tests
  -- TODO: make debug level configurable
  for pos_id in pairs(d) do
    local test_data = d[pos_id]
    if test_data.duplicate_test_detected == true then
      vim.notify(
        "Duplicate test name detected: "
          .. test_data.go_test_data.package
          .. "/"
          .. test_data.go_test_data.name,
        vim.log.levels.WARN
      )
    end
  end
end

--- Convert internal results to Neotest results.
--- @param spec neotest.RunSpec
--- @param result neotest.StrategyResult
--- @param d table<string, InternalResult>
--- @param gotest_output table
--- @return table<string, neotest.Result>
function M.to_neotest_results(spec, result, d, gotest_output)
  --- Neotest results.
  --- @type table<string, neotest.Result>
  local neotest_results = {}

  -- populate all test results onto the Neotest format.
  for pos_id in pairs(d) do
    local test_data = d[pos_id]
    local test_output_path = vim.fs.normalize(async.fn.tempname())
    async.fn.writefile(test_data.output, test_output_path)
    neotest_results[pos_id] = {
      status = test_data.status,
      errors = test_data.errors,
      output = test_output_path, -- NOTE: could be slow when running many tests?
    }
  end

  --- Test command (e.g. 'go test') status.
  --- @type neotest.ResultStatus
  local test_command_status = "skipped"
  if result.code == 0 then
    test_command_status = "passed"
  else
    test_command_status = "failed"
  end

  --- Full 'go test' output (parsed from JSON).
  --- @type table
  local full_output = {}
  local test_command_output_path = vim.fs.normalize(async.fn.tempname())
  for _, line in ipairs(gotest_output) do
    if line.Action == "output" then
      table.insert(full_output, line.Output)
    end
  end
  async.fn.writefile(full_output, test_command_output_path)

  -- register properties on the directory node that was run
  neotest_results[spec.context.id] = {
    status = test_command_status,
    output = test_command_output_path,
  }

  return neotest_results
end

return M
