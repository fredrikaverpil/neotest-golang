local async = require("neotest.async")

local options = require("neotest-golang.options")
local convert = require("neotest-golang.convert")
local json = require("neotest-golang.json")

local M = {}

--- @async
--- @param spec neotest.RunSpec
--- @param result neotest.StrategyResult
--- @param tree neotest.Tree
--- @return table<string, neotest.Result>
function M.results(spec, result, tree)
  ---@type table<string, neotest.Result>
  local results = {}
  results[spec.context.id] = {
    ---@type neotest.ResultStatus
    status = "skipped", -- default value
  }

  if spec.context.skip then
    return results
  end

  --- @type boolean
  local no_tests_to_run = false

  --- @type table
  local raw_output = async.fn.readfile(result.output)

  --- @type string
  local test_filepath = spec.context.test_filepath
  local test_filename = vim.fn.fnamemodify(test_filepath, ":t")
  --- @type table
  local test_result = {}
  --- @type neotest.Error[]
  local errors = {}
  --- @type table
  local gotest_output = json.process_gotest_output(raw_output)

  for _, line in ipairs(gotest_output) do
    if line.Action == "output" and line.Output ~= nil then
      -- record output, prints to output panel
      table.insert(test_result, line.Output)

      -- if test was not run, mark it as skipped

      -- if line contains "no test files" or "no tests to run", mark as skipped
      if string.match(line.Output, "no tests to run") then
        no_tests_to_run = true
      end
    end

    -- record an error
    if result.code ~= 0 and line.Output ~= nil then
      ---@type string
      local matched_line_number =
        string.match(line.Output, test_filename .. ":(%d+):")

      if matched_line_number ~= nil then
        -- attempt to parse the line number...
        ---@type number | nil
        local line_number = tonumber(matched_line_number)

        if line_number ~= nil then
          -- log the error along with its line number (for diagnostics)

          ---@type string
          local message = string.match(line.Output, ":%d+: (.*)")

          ---@type neotest.Error
          local error = {
            message = message,
            line = line_number - 1, -- neovim lines are 0-indexed
          }
          table.insert(errors, error)
        end
      end
    end
  end

  if no_tests_to_run then
    if options.get().warn_test_not_executed == true then
      vim.notify(
        "Could not execute test: "
          .. convert.to_gotest_test_name(spec.context.id),
        vim.log.levels.WARN
      )
    end
  else
    -- assign status code, as long as the test was found
    if result.code == 0 then
      results[spec.context.id].status = "passed"
    else
      results[spec.context.id].status = "failed"
    end
  end

  -- write json_decoded to file
  local parsed_output_path = vim.fs.normalize(async.fn.tempname())
  async.fn.writefile(test_result, parsed_output_path)

  ---@type table<string, neotest.Result>
  results[spec.context.id].output = parsed_output_path
  results[spec.context.id].errors = errors

  return results
end

return M
