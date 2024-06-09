local async = require("neotest.async")

local M = {}

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function M.results(spec, result, tree)
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
  local jsonlines = require("neotest-golang.json").process_json(raw_output)

  for _, line in ipairs(jsonlines) do
    if line.Action == "output" and line.Output ~= nil then
      -- record output, prints to output panel
      table.insert(test_result, line.Output)
    end

    if result.code ~= 0 and line.Output ~= nil then
      -- record an error
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

return M
