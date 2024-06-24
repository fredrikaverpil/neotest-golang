local async = require("neotest.async")

local options = require("neotest-golang.options")
local convert = require("neotest-golang.convert")
local json = require("neotest-golang.json")
local utils = require("neotest-golang.utils")

--- @class TestData
--- @field status neotest.ResultStatus
--- @field short? string Shortened output string
--- @field errors? neotest.Error[]
--- @field neotest_data neotest.Position
--- @field gotest_data GoTestData
--- @field duplicate_test_detected boolean

--- @class GoTestData
--- @field name string Go test name.
--- @field pkg string Go package.
--- @field output? string[] Go test output.

local M = {}

--- Process the results from the test command executing all tests in a
--- directory.
--- @param spec neotest.RunSpec
--- @param result neotest.StrategyResult
--- @param tree neotest.Tree
--- @return table<string, neotest.Result>
function M.results(spec, result, tree)
  --- The Neotest position tree node for this execution.
  --- @type neotest.Position
  local pos = tree:data()

  --- The raw output from the 'go test -json' command.
  --- @type table
  local raw_output = async.fn.readfile(result.output)

  --- The 'go test' JSON output, converted into a lua table.
  --- @type table
  local gotest_output = json.process_gotest_output(raw_output)

  --- The 'go list -json' output, converted into a lua table.
  local golist_output = spec.context.golist_output

  --- @type table<string, neotest.Result>
  local neotest_result = {}

  --- Test command (e.g. 'go test') status.
  --- @type neotest.ResultStatus
  local test_command_status = "skipped"
  if spec.context.skip == true then
    test_command_status = "skipped"
  elseif result.code == 0 then
    test_command_status = "passed"
  else
    test_command_status = "failed"
  end

  --- Full 'go test' output (parsed from JSON).
  --- @type table
  local o = {}
  local test_command_output_path = vim.fs.normalize(async.fn.tempname())
  for _, line in ipairs(gotest_output) do
    if line.Action == "output" then
      table.insert(o, line.Output)
    end
  end
  async.fn.writefile(o, test_command_output_path)

  -- register properties on the directory node that was run
  neotest_result[pos.id] = {
    status = test_command_status,
    output = test_command_output_path,
  }

  -- if the test execution was skipped, return early
  if spec.context.skip == true then
    return neotest_result
  end

  --- Internal data structure to store test result data.
  --- @type table<string, TestData>
  local res = M.aggregate_data(tree, gotest_output, golist_output)

  -- DEBUG: enable the following to see the internal test result data.
  -- vim.notify(vim.inspect(res), vim.log.levels.DEBUG)

  -- show various warnings
  M.show_warnings(res)

  -- Convert internal test result data into final Neotest result.
  local test_results = M.to_neotest_result(spec, result, res, gotest_output)
  for k, v in pairs(test_results) do
    neotest_result[k] = v
  end

  -- DEBUG: enable the following to see the final Neotest result.
  -- vim.notify(vim.inspect(neotest_results), vim.log.levels.DEBUG)

  return neotest_result
end

--- Aggregate neotest data and 'go test' output data.
--- @param tree neotest.Tree
--- @param gotest_output table
--- @param golist_output table
--- @return table<string, TestData>
function M.aggregate_data(tree, gotest_output, golist_output)
  local res = M.gather_neotest_data_and_set_defaults(tree)
  res =
    M.decorate_with_go_package_and_test_name(res, gotest_output, golist_output)
  res = M.decorate_with_go_test_results(res, gotest_output)
  return res
end

--- Generate the internal test result data which will be used by neotest-golang
--- before handing over the final results onto Neotest.
--- @param tree neotest.Tree
--- @return table<string, TestData>
function M.gather_neotest_data_and_set_defaults(tree)
  --- Internal data structure to store test result data.
  --- @type table<string, TestData>
  local res = {}

  --- Table storing the name of the test (position.id) and the number of times
  --- it was found in the tree.
  --- @type table<string, number>
  local dupes = {}

  for _, node in tree:iter_nodes() do
    --- @type neotest.Position
    local pos = node:data()

    if pos.type == "test" then
      res[pos.id] = {
        status = "skipped",
        errors = {},
        neotest_data = pos,
        gotest_data = {
          name = "",
          pkg = "",
          output = {},
        },
        duplicate_test_detected = false,
      }

      -- detect duplicate test names
      if dupes[pos.id] == nil then
        dupes[pos.id] = 1
      else
        dupes[pos.id] = dupes[pos.id] + 1
        res[pos.id].duplicate_test_detected = true
      end
    end
  end
  return res
end

--- Decorate the internal test result data with go package and test name.
--- This is an important step, in which we figure out exactly which test output
--- belongs to which test in the Neotest position tree.
---
--- The strategy here is to loop over the Neotest position data, and figure out
--- which position belongs to a specific Go package (using the output from
--- 'go list -json').
---
--- If a test cannot be decorated with Go package/test name data, an association
--- warning will be shown (see show_warnings).
--- @param res table<string, TestData>
--- @param gotest_output table
--- @param golist_output table
--- @return table<string, TestData>
function M.decorate_with_go_package_and_test_name(
  res,
  gotest_output,
  golist_output
)
  for pos_id, test_data in pairs(res) do
    local match = nil
    local folderpath = vim.fn.fnamemodify(test_data.neotest_data.path, ":h")
    local tweaked_pos_id = pos_id:gsub(" ", "_")
    tweaked_pos_id = tweaked_pos_id:gsub('"', "")
    tweaked_pos_id = tweaked_pos_id:gsub("::", "/")

    for _, golistline in ipairs(golist_output) do
      if folderpath == golistline.Dir then
        for _, gotestline in ipairs(gotest_output) do
          if gotestline.Action == "run" and gotestline.Test ~= nil then
            if gotestline.Package == golistline.ImportPath then
              local pattern = convert.to_lua_pattern(folderpath)
                .. "/(.-)/"
                .. convert.to_lua_pattern(gotestline.Test)
                .. "$"
              match = tweaked_pos_id:find(pattern, 1, false)
              if match ~= nil then
                test_data.gotest_data.pkg = gotestline.Package
                test_data.gotest_data.name = gotestline.Test
                break
              end
            end
            if match ~= nil then
              break
            end
          end
          if match ~= nil then
            break
          end
        end
        if match ~= nil then
          break
        end
      end
    end
  end

  return res
end

--- Decorate the internal test result data with data from the 'go test' output.
--- @param res table<string, TestData>
--- @param gotest_output table
--- @return table<string, TestData>
function M.decorate_with_go_test_results(res, gotest_output)
  for pos_id, test_data in pairs(res) do
    for _, line in ipairs(gotest_output) do
      if
        test_data.gotest_data.pkg == line.Package
        and test_data.gotest_data.name == line.Test
      then
        -- record test status
        if line.Action == "pass" then
          test_data.status = "passed"
        elseif line.Action == "fail" then
          test_data.status = "failed"
        elseif line.Action == "output" then
          test_data.gotest_data.output =
            vim.list_extend(test_data.gotest_data.output, { line.Output })

          -- determine test filename
          local test_filename = "_test.go" -- approximate test filename
          if test_data.neotest_data ~= nil then
            -- node data is available, get the exact test filename
            local test_filepath = test_data.neotest_data.path
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
              table.insert(test_data.errors, {
                line = line_number - 1, -- neovim lines are 0-indexed
                message = message,
              })
            end
          end
        end
      end
    end
  end
  return res
end

--- Show warnings.
--- @param d table<string, TestData>
--- @return nil
function M.show_warnings(d)
  if options.get().dev_notifications == true then
    -- warn if Go package/test is missing for given Neotest position id (Neotest tree node).
    --- @type table<string>
    local position_ids = {}
    for pos_id, test_data in pairs(d) do
      if
        test_data.gotest_data.pkg == "" or test_data.gotest_data.name == ""
      then
        table.insert(position_ids, pos_id)
      end
    end
    if #position_ids > 0 then
      vim.notify(
        "Test(s) not associated (not found/executed):\n"
          .. table.concat(position_ids, "\n"),
        vim.log.levels.DEBUG
      )
    end
  end

  if options.get().warn_test_name_dupes == true then
    -- warn about duplicate tests
    local test_dupes = {}
    for pos_id, test_data in pairs(d) do
      if test_data.duplicate_test_detected == true then
        table.insert(
          test_dupes,
          test_data.gotest_data.pkg .. "/" .. test_data.gotest_data.name
        )
      end
    end
    if #test_dupes > 0 then
      vim.notify(
        "Duplicate test name(s) detected:\n" .. table.concat(test_dupes, "\n"),
        vim.log.levels.WARN
      )
    end
  end
end

--- Populate final Neotest results based on internal test result data.
--- @param spec neotest.RunSpec
--- @param result neotest.StrategyResult
--- @param res table<string, TestData>
--- @param gotest_output table
--- @return table<string, neotest.Result>
function M.to_neotest_result(spec, result, res, gotest_output)
  --- Neotest results.
  --- @type table<string, neotest.Result>
  local neotest_result = {}

  -- populate all test results onto the Neotest format.
  for pos_id, test_data in pairs(res) do
    local test_output_path = vim.fs.normalize(async.fn.tempname())
    async.fn.writefile(test_data.gotest_data.output, test_output_path)
    neotest_result[pos_id] = {
      status = test_data.status,
      errors = test_data.errors,
      output = test_output_path, -- NOTE: could be slow when running many tests?
    }
  end

  return neotest_result
end

return M
