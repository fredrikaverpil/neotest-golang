local async = require("neotest.async")

local convert = require("neotest-golang.convert")
local json = require("neotest-golang.json")

local M = {}

-- Find the common path of two folderpaths.
function M.find_common_path(path1, path2)
  local common = {}
  local path1_parts = vim.split(path1, "/")
  local path2_parts = vim.split(path2, "/")
  for i = #path1_parts, 1, -1 do
    if path1_parts[i] == path2_parts[#path2_parts] then
      table.insert(common, 1, path1_parts[i])
      table.remove(path2_parts)
    else
      break
    end
  end
  return table.concat(common, "/")
end

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

  -- record neotest node data
  local duplicates = {}
  for idx, node in tree:iter_nodes() do
    local node_data = node:data()

    if idx == 1 then
      -- Example node:
      -- {
      --   id = "/Users/fredrik/code/public/neotest-golang/backend/internal/core/model",
      --   name = "model",
      --   path = "/Users/fredrik/code/public/neotest-golang/backend/internal/core/model",
      --   type = "dir"
      -- }

      -- vim.notify(vim.inspect(node_data))
    end

    if node_data.type == "test" then
      -- Example node:
      -- {
      --   id = "/Users/fredrik/code/public/neotest-golang/backend/internal/core/model/something_test.go::TestSomething:"a sub test",
      --   name = "a sub test",
      --   path = "/Users/fredrik/code/public/neotest-golang/backend/internal/core/model/something_test.go",
      --   range = { 12, 0, 164, 1 },
      --   type = "test"
      -- },

      internal_results[node_data.id] = {
        status = "skipped",
        output = {},
        errors = {},
        neotest_node_data = node_data,
        go_test_data = {},
        duplicate_test_detected = false,
      }

      -- detect duplicates
      if duplicates[node_data.id] == nil then
        duplicates[node_data.id] = 1
      else
        duplicates[node_data.id] = duplicates[node_data.id] + 1
        internal_results[node_data.id].duplicate_test_detected = true
      end
    end
  end

  -- associate neotest node data with go test package and test name
  for neotest_node_id in pairs(internal_results) do
    for _, line in ipairs(jsonlines) do
      -- Example line:
      -- {
      --   Action = "pass",
      --   Elapsed = 0,
      --   Package = "github.com/fredrikaverpil/neotest-golang/internal/core/model",
      --   Test = "TestSomething/a_sub_test",
      --   Time = "2024-06-13T22:33:28.302953+02:00"
      -- }

      if line.Action == "run" and line.Test ~= nil then
        -- remove filename from path
        local folderpath = vim.fn.fnamemodify(
          internal_results[neotest_node_id].neotest_node_data.path,
          ":h"
        ) -- TODO: would be nicer if this was handled by the common_parts function

        local match = nil
        local partial_path = M.find_common_path(line.Package, folderpath)

        if partial_path ~= "" then
          local tweaked_neotest_node_id = neotest_node_id:gsub(" ", "_")
          tweaked_neotest_node_id = tweaked_neotest_node_id:gsub('"', "")
          tweaked_neotest_node_id = tweaked_neotest_node_id:gsub("::", "/")

          local combined_pattern = convert.to_lua_pattern(partial_path)
            .. "/(.-)/"
            .. convert.to_lua_pattern(line.Test)
            .. "$"

          -- TODO: how to handle root level of package, when there is no common path

          match = tweaked_neotest_node_id:match(combined_pattern)
        end
        if match ~= nil then
          internal_results[neotest_node_id].go_test_data = {
            package = line.Package,
            name = line.Test,
          }

          break
        end
      end
    end
  end

  for neotest_node_id in pairs(internal_results) do
    for _, line in ipairs(jsonlines) do
      if
        internal_results[neotest_node_id].go_test_data.package == line.Package
        and internal_results[neotest_node_id].go_test_data.name == line.Test
      then
        -- record test status
        if line.Action == "pass" then
          internal_results[neotest_node_id].status = "passed"
        elseif line.Action == "fail" then
          internal_results[neotest_node_id].status = "failed"
        elseif line.Action == "output" then
          -- append line.Output to output field
          internal_results[neotest_node_id].output = vim.list_extend(
            internal_results[neotest_node_id].output,
            { line.Output }
          )

          -- determine test filename
          local test_filename = "_test.go" -- approximate test filename
          if internal_results[neotest_node_id].neotest_node_data ~= nil then
            -- node data is available, get the exact test filename
            local test_filepath =
              internal_results[neotest_node_id].neotest_node_data.path
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
              table.insert(internal_results[neotest_node_id].errors, {
                line = line_number - 1, -- neovim lines are 0-indexed
                message = message,
              })
            end
          end
        end
      end
    end
  end

  -- warn if Go package/test is missing from tree node.
  -- TODO: make configurable to skip this or use different log level?
  for neotest_node_id in pairs(internal_results) do
    if internal_results[neotest_node_id].go_test_data.name == "" then
      vim.notify(
        "Unable to associate go package/test with neotest tree node: "
          .. neotest_node_id,
        vim.log.levels.WARN
      )
    end
  end

  -- TODO: warn (or debug log) if Go test was detected, but is not found in the AST/treesitter tree.

  -- warn about duplicate tests
  -- TODO: make debug level configurable
  for neotest_node_id in pairs(internal_results) do
    local test_properties = internal_results[neotest_node_id]
    if test_properties.duplicate_test_detected == true then
      vim.notify(
        "Duplicate test name detected: "
          .. test_properties.go_test_data.package
          .. "/"
          .. test_properties.go_test_data.name,
        vim.log.levels.WARN
      )
    end
  end

  -- convert internal results to neotest results
  for neotest_node_id in pairs(internal_results) do
    local test_properties = internal_results[neotest_node_id]
    local test_output_path = vim.fs.normalize(async.fn.tempname())
    async.fn.writefile(test_properties.output, test_output_path)
    neotest_results[neotest_node_id] = {
      status = test_properties.status,
      errors = test_properties.errors,
      output = test_output_path, -- NOTE: could be slow when running many tests?
    }
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
    -- vim.notify(vim.inspect(line))
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
  -- vim.notify(vim.inspect(internal_results), vim.log.levels.DEBUG)

  return neotest_results
end

return M
