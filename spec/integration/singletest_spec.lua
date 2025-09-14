local _ = require("plenary")
local options = require("neotest-golang.options")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Integration: individual test example", function()
  it(
    "individual test pattern targeting reports test discovery and execution for specific test",
    function()
      -- ===== ARRANGE =====
      ---@type NeotestGolangOptions
      local test_options =
        { runner = "gotestsum", warn_test_results_missing = false }
      options.set(test_options)

      local test_filepath = vim.uv.cwd()
        .. "/tests/go/internal/singletest/singletest_test.go"
      test_filepath = integration.normalize_path(test_filepath)

      -- Expected complete adapter execution result - only TestOne should run
      ---@type AdapterExecutionResult
      local want = {
        results = {
          -- Directory-level result (created by file aggregation)
          [vim.fs.dirname(test_filepath)] = {
            status = "passed",
            errors = {},
          },
          -- File-level result
          [test_filepath] = {
            status = "passed",
            errors = {},
          },
          -- Individual test results - ONLY TestOne should be present!
          [test_filepath .. "::TestOne"] = {
            status = "passed",
            errors = {},
          },
          -- TestTwo and TestThree should NOT be in the results since we're targeting only TestOne
        },
        run_spec = {
          command = {}, -- this will be replaced in the assertion
          context = {
            pos_id = test_filepath .. "::TestOne",
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
      local got = integration.execute_adapter_direct(test_filepath .. "::TestOne")

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
      want.run_spec.context.pos_id = got.run_spec.context.pos_id
      want.run_spec.context.process_test_results =
        got.run_spec.context.process_test_results
      want.strategy_result.output = got.strategy_result.output

      -- Copy dynamic fields for expected results only
      for pos_id, result in pairs(got.results) do
        if want.results[pos_id] then
          -- copy output path if it exists
          if result.output then
            want.results[pos_id].output = result.output
          end
          -- copy short field if it exists
          if result.short then
            want.results[pos_id].short = result.short
          end
        end
      end

      assert.are.same(vim.inspect(want), vim.inspect(got))
    end
  )
end)
