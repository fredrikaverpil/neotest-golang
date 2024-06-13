local async = require("neotest.async")

local convert = require("neotest-golang.convert")
local json = require("neotest-golang.json")

local M = {}

---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
function M.results(spec, result, tree)
  ---@type table
  local raw_output = async.fn.readfile(result.output)

  ---@type List<table>
  local jsonlines = json.process_json(raw_output)

  ---@type List
  local full_test_output = {}

  --- neotest results
  ---@type table<string, neotest.Result>
  local neotest_results = {}

  --- internal results struct
  ---@type table<string, table>
  local internal_results = {}

  -- record test names
  for _, line in ipairs(jsonlines) do
    if line.Action == "run" and line.Test ~= nil then
      internal_results[line.Test] = {
        status = "skipped",
        output = {},
        errors = {},
        node_data = nil,
      }
    end
  end

  -- record test status
  for _, line in ipairs(jsonlines) do
    if line.Action == "pass" and line.Test ~= nil then
      internal_results[line.Test].status = "passed"
    elseif line.Action == "fail" and line.Test ~= nil then
      internal_results[line.Test].status = "failed"
    end
  end

  -- associate internal results with neotest node data
  for test_name, test_properties in pairs(internal_results) do
    local test_name_pattern = convert.to_neotest_test_name_pattern(test_name)
    for _, node in tree:iter_nodes() do
      local node_data = node:data()

      -- WARNING: workarounds
      local tweaked_node_data_id = node_data.id:gsub('"', "") -- workaround, since we cannot know where double quotes might appear
      local tweaked_node_data_id = tweaked_node_data_id:gsub("_", " ") -- NOTE: look into making this more clear...

      if
        string.find(node_data.path, spec.context.id, 1, true)
        and string.find(tweaked_node_data_id, test_name_pattern, 1, false)
      then
        if internal_results[test_name].node_data ~= nil then
          vim.notify(
            "Multiple tests with name: " .. test_name,
            vim.log.levels.WARN
          )
        end
        internal_results[test_name].node_data = node_data
        -- FIXME: likely add a break here so to avoid iterating further...
        -- break
      end
    end
  end

  -- warn if node data is missing for the test
  local missing_node_data = {}
  for test_name, test_properties in pairs(internal_results) do
    if internal_results[test_name].node_data == nil then
      missing_node_data[test_name] = true
    end
  end
  -- debug log if missing node data
  if vim.tbl_count(missing_node_data) > 0 then
    vim.notify(
      "Missing node data was found for test(s)."
        .. "When node data is missing, this indicates that the test wast not "
        .. "successfully detected by the AST/treesitter parsing. As a result "
        .. "inaccurate error messages may be displayed (or not displayed at all). "
        .. "Another, more severe problem, is that the test status might not be "
        .. "performed, resulting in false failures.",
      vim.log.levels.DEBUG
    )
    for test_name, _ in pairs(missing_node_data) do
      vim.notify(
        "Missing node data for test: " .. test_name,
        vim.log.levels.DEBUG
      )
    end
  end

  -- record error output (requires neotest node data)
  local node_data_not_found = {}
  for _, line in ipairs(jsonlines) do
    if line.Action == "output" and line.Output ~= nil and line.Test ~= nil then
      -- append line.Output to output field
      internal_results[line.Test].output =
        vim.list_extend(internal_results[line.Test].output, { line.Output })

      -- determine test filename
      local test_filename = "_test.go" -- approximate test filename
      if node_data_not_found[line.Test] ~= nil then
        -- node data is available, get the exact test filename
        local test_filepath = internal_results[line.Test].node_data.path
        test_filename = vim.fn.fnamemodify(test_filepath, ":t")
      end

      -- search for error message and line number
      local matched_line_number =
        string.match(line.Output, test_filename .. ":(%d+):")
      if matched_line_number ~= nil then
        local line_number = tonumber(matched_line_number)
        local message = string.match(line.Output, test_filename .. ":%d+: (.*)")
        if line_number ~= nil and message ~= nil then
          table.insert(internal_results[line.Test].errors, {
            line = line_number - 1, -- neovim lines are 0-indexed
            message = message,
          })
        end
      end
    end
  end

  -- populate neotest results
  for test_name, test_properties in pairs(internal_results) do
    if test_properties.node_data ~= nil then
      local test_output_path = vim.fs.normalize(async.fn.tempname())
      async.fn.writefile(test_properties.output, test_output_path)
      neotest_results[test_properties.node_data.id] = {
        status = test_properties.status,
        output = test_output_path, -- NOTE: could be slow when running many tests?
        errors = test_properties.errors,
      }
    end
  end

  ---@type neotest.ResultStatus
  local test_command_status = "skipped"
  if result.code == 0 then
    test_command_status = "passed"
  else
    test_command_status = "failed"
  end

  -- write full test command output
  local parsed_output_path = vim.fs.normalize(async.fn.tempname())
  for _, line in ipairs(jsonlines) do
    if line.Action == "output" then
      table.insert(full_test_output, line.Output)
    end
  end
  async.fn.writefile(full_test_output, parsed_output_path)

  -- register properties on the directory node that was run
  neotest_results[spec.context.id] = {
    status = test_command_status,
    output = parsed_output_path,
  }

  -- FIXME: once output is parsed, erase file contents, so to avoid JSON in
  -- output panel. This is a workaround for now, only because of
  -- https://github.com/nvim-neotest/neotest/issues/391
  vim.fn.writefile({ "" }, result.output)

  -- DEBUG: enable the following to see the collected data
  -- vim.notify(vim.inspect(internal_results), vim.log.levels.INFO)

  return neotest_results
end

return M
