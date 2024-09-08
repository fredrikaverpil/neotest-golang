--- This file is centered around the parsing/processing of test execution output
--- and assembling of the final results to hand back over to Neotest.

local async = require("neotest.async")

local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")
local lib = require("neotest-golang.lib")

--- @class RunspecContext
--- @field pos_id string Neotest tree position id.
--- @field golist_data table<string, string> The 'go list' JSON data (lua table).
--- @field errors? table<string> Non-gotest errors to show in the final output.
--- @field process_test_results boolean If true, parsing of test output will occur.
--- @field test_output_json_filepath? string Gotestsum JSON filepath.

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

--- Process the results from the test command.
--- @param spec neotest.RunSpec
--- @param result neotest.StrategyResult
--- @param tree neotest.Tree
--- @return table<string, neotest.Result>
function M.test_results(spec, result, tree)
  --- @type RunspecContext
  local context = spec.context

  --- Test command (e.g. 'go test') status.
  --- @type neotest.ResultStatus
  local result_status = nil
  if context.errors ~= nil and #context.errors > 0 then
    result_status = "failed"
  elseif result.code == 0 then
    result_status = "passed"
  elseif result.code > 0 then
    result_status = "failed"
  else
    result_status = "skipped"
  end

  --- Final Neotest results, the way Neotest wants it returned.
  --- @type table<string, neotest.Result>
  local neotest_result = {}

  -- return early if test result processing is not desired.
  if context.process_test_results == false then
    neotest_result[context.pos_id] = {
      status = result_status,
    }
    return neotest_result
  end

  --- The Neotest position tree node for this execution.
  --- @type neotest.Position
  local pos = tree:data()

  --- The runner to use for running tests.
  --- @type string
  local runner = options.get().runner

  --- The raw output from the test command.
  --- @type table
  local raw_output = {}
  if runner == "go" then
    raw_output = async.fn.readfile(result.output)
  elseif runner == "gotestsum" then
    raw_output = async.fn.readfile(context.test_output_json_filepath)
  end
  logger.debug({ "Raw 'go test' output: ", raw_output })

  --- The 'go list -json' output, converted into a lua table.
  local golist_output = context.golist_data

  --- Go test output.
  --- @type table
  local gotest_output = lib.json.decode_from_table(raw_output, true)

  --- Internal data structure to store test result data.
  --- @type table<string, TestData>
  local res = M.aggregate_data(tree, gotest_output, golist_output)

  logger.debug({ "Final internal test result data", res })

  -- show various warnings
  M.show_warnings(res)

  -- convert internal test result data into Neotest result.
  local test_results = M.to_neotest_result(res)
  for k, v in pairs(test_results) do
    neotest_result[k] = v
  end

  -- override the position which was executed with the full
  -- command execution output.
  local cmd_output = M.filter_gotest_output(gotest_output)
  cmd_output = vim.list_extend(context.errors or {}, cmd_output)
  if #cmd_output == 0 and result.code ~= 0 and runner == "gotestsum" then
    -- special case; gotestsum does not capture compilation errors from stderr.
    cmd_output = { "Failed to run 'go test'. Compilation error?" }
  end
  local cmd_output_path = vim.fs.normalize(async.fn.tempname())
  async.fn.writefile(cmd_output, cmd_output_path)
  if neotest_result[pos.id] == nil then
    -- set status and output.
    neotest_result[pos.id] = {
      status = result_status,
      output = cmd_output_path,
    }
  else
    -- only override status and output, keep errors.
    neotest_result[pos.id].status = result_status
    neotest_result[pos.id].output = cmd_output_path
  end

  logger.debug({ "Final Neotest result data", neotest_result })

  return neotest_result
end

--- Filter on the Output-type parts of the 'go test' output.
--- @param gotest_output table
--- @return table<string>
function M.filter_gotest_output(gotest_output)
  local o = {}
  for _, line in ipairs(gotest_output) do
    if line.Action == "output" then
      table.insert(o, line.Output)
    end
  end
  return o
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
              local pattern = lib.convert.to_lua_pattern(folderpath)
                .. lib.find.os_path_sep
                .. "(.-)"
                .. "/"
                .. lib.convert.to_lua_pattern(gotestline.Test)
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
        line.Package == test_data.gotest_data.pkg
        and (
          line.Test == test_data.gotest_data.name
          or lib.string.starts_with(
            line.Test,
            test_data.gotest_data.name .. "/"
          )
        )
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
  -- warn if Go package/test is missing for given Neotest position id (Neotest tree node).
  if options.get().warn_test_not_executed == true then
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
      logger.warn({
        "Test(s) not associated (not found/executed): ",
        position_ids,
      })
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
      logger.warn({ "Duplicate test name(s) detected: ", test_dupes })
    end
  end
end

--- Populate final Neotest results based on internal test result data.
--- @param res table<string, TestData>
--- @return table<string, neotest.Result>
function M.to_neotest_result(res)
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
