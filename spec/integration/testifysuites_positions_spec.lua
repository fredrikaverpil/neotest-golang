local _ = require("plenary")
local find = require("neotest-golang.lib.find")
local options = require("neotest-golang.options")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Integration: testify suites positions test", function()
  it(
    "file reports test discovery and execution for testify suite patterns",
    function()
      -- ===== ARRANGE =====
      local test_options = options.get()
      test_options.runner = "gotestsum"
      test_options.testify_enabled = true
      test_options.log_level = vim.log.levels.DEBUG
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
          -- Parent directory result
          [find.get_directory(find.get_directory(position_id))] = {
            status = "passed",
            errors = {},
          },
          -- Directory-level result (created by file aggregation)
          [find.get_directory(position_id)] = {
            status = "passed",
            errors = {},
          },
          -- File-level result
          [position_id] = {
            status = "passed",
            errors = {},
          },
          -- All the individual test method results
          [position_id .. "::TestExampleTestSuite2::TestExample"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestExampleTestSuite2::TestExample2"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestExampleTestSuite::TestExample"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestExampleTestSuite::TestExample2"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestExampleTestSuite::TestSubTestOperand1"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestExampleTestSuite::TestSubTestOperand1::"subtest"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestExampleTestSuite::TestSubTestOperand2"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestExampleTestSuite::TestSubTestOperand2::"subtest"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestTrivial"] = {
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

      -- ===== ASSERT =====

      -- Copy dynamic run_spec fields
      want.run_spec.command = got.run_spec.command
      want.run_spec.cwd = got.run_spec.cwd
      want.run_spec.env = got.run_spec.env
      want.run_spec.stream = got.run_spec.stream
      want.run_spec.strategy = got.run_spec.strategy
      want.run_spec.context.golist_data = got.run_spec.context.golist_data
      want.run_spec.context.stop_filestream =
        got.run_spec.context.stop_filestream
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
