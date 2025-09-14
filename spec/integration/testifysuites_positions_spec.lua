local _ = require("plenary")
local options = require("neotest-golang.options")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Integration: testify suites positions test", function()
  it(
    "file reports test discovery and execution for testify suite patterns",
    function()
      -- ===== ARRANGE =====
      ---@type NeotestGolangOptions
      local test_options =
        { runner = "gotestsum", warn_test_results_missing = false }
      options.set(test_options)

      local position_id = vim.uv.cwd()
        .. "/tests/go/internal/testifysuites/positions_test.go"
      position_id = integration.normalize_path(position_id)

      -- ===== ACT =====
      ---@type AdapterExecutionResult
      local got = integration.execute_adapter_direct(position_id)

      -- Expected complete adapter execution result
      ---@type AdapterExecutionResult
      local want = {
        results = {
          -- Directory-level result (created by file aggregation)
          [vim.fs.dirname(position_id)] = {
            status = "passed",
            errors = {},
          },
          -- File-level result
          [position_id] = {
            status = "passed",
            errors = {},
          },
          -- Individual test results
          [position_id .. "::TestExampleTestSuite"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestExampleTestSuite2"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestTrivial"] = {
            status = "passed",
            errors = {},
          },
        },
        run_spec = {
          context = {
            pos_id = position_id,
          },
        },
        strategy_result = {
          code = 0,
        },
      }

      -- ===== ASSERT =====

      -- Copy dynamic run_spec fields
      want.run_spec.command = got.run_spec.command
      want.run_spec.cwd = got.run_spec.cwd
      want.run_spec.env = got.run_spec.env
      want.run_spec.stream = got.run_spec.stream
      want.run_spec.strategy = got.run_spec.strategy
      want.run_spec.context.golist_data = got.run_spec.context.golist_data
      want.run_spec.context.stop_stream = got.run_spec.context.stop_stream
      want.run_spec.context.test_output_json_filepath =
        got.run_spec.context.test_output_json_filepath

      -- Copy dynamic strategy_result fields
      want.strategy_result.output = got.strategy_result.output

      -- Copy tree field if present
      want.tree = got.tree

      -- Copy dynamic output paths for all results
      for pos_id, result in pairs(got.results) do
        if want.results[pos_id] then
          -- Copy output path if it exists
          if result.output then
            want.results[pos_id].output = result.output
          end
          -- Copy short field if it exists
          if result.short then
            want.results[pos_id].short = result.short
          end
        end
      end

      assert.are.same(
        vim.inspect(want),
        vim.inspect(got),
        "Complete adapter execution result should match"
      )
    end
  )
end)
