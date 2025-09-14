local _ = require("plenary")
local options = require("neotest-golang.options")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Integration: multifile test", function()
  it(
    "directory testing runs both TestOne and TestTwo from multiple files",
    function()
      -- ===== ARRANGE =====
      local test_options = options.get()
      test_options.runner = "gotestsum"
      options.set(test_options)

      local position_id = vim.uv.cwd() .. "/tests/go/internal/multifile"
      position_id = integration.normalize_path(position_id)

      local first = position_id .. "/first_file_test.go"
      local second = position_id .. "/second_file_test.go"
      first = integration.normalize_path(first)
      second = integration.normalize_path(second)

      ---@type AdapterExecutionResult
      local want = {
        results = {
          -- Directory-level result
          [position_id] = {
            status = "passed",
            errors = {},
          },
          -- File-level results
          [first] = {
            status = "passed",
            errors = {},
          },
          [second] = {
            status = "passed",
            errors = {},
          },
          -- Individual test results
          [first .. "::TestOne"] = {
            status = "passed",
            errors = {},
          },
          [second .. "::TestTwo"] = {
            status = "passed",
            errors = {},
          },
        },
        run_spec = {
          command = {}, -- this will be replaced in the assertion
          context = {
            pos_id = position_id,
          },
        },
        strategy_result = {
          code = 0,
        },
        tree = {
          -- this will be replaced in the assertion
          _children = {},
          _nodes = {},
          _key = function()
            return ""
          end,
        },
      }

      -- ===== ACT =====
      ---@type AdapterExecutionResult
      local got = integration.execute_adapter_direct(position_id)

      -- ===== ASSERT =====
      want.tree = got.tree
      want.run_spec.cwd = got.run_spec.cwd
      want.run_spec.command = got.run_spec.command
      want.run_spec.env = got.run_spec.env
      want.run_spec.stream = got.run_spec.stream
      want.run_spec.strategy = got.run_spec.strategy
      want.run_spec.context.golist_data = got.run_spec.context.golist_data
      want.run_spec.context.stop_stream = got.run_spec.context.stop_stream
      want.run_spec.context.test_output_json_filepath =
        got.run_spec.context.test_output_json_filepath
      want.strategy_result.output = got.strategy_result.output
      for pos_id, result in pairs(got.results) do
        if want.results[pos_id] then
          if result.output then
            want.results[pos_id].output = result.output
          end
          if result.short then
            want.results[pos_id].short = result.short
          end
        end
      end

      assert.are.same(vim.inspect(want), vim.inspect(got))
    end
  )
end)
