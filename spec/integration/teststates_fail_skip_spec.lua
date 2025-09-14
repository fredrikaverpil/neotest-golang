local _ = require("plenary")
local options = require("neotest-golang.options")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Integration: fail/skip paths", function()
  it("file reports failed status when containing failing tests", function()
    -- ===== ARRANGE =====
    ---@type NeotestGolangOptions
    local test_options =
      { runner = "gotestsum", warn_test_results_missing = false }
    options.set(test_options)

    local position_id = vim.uv.cwd()
      .. "/tests/go/internal/teststates/mixed/fail_skip_test.go"
    position_id = integration.normalize_path(position_id)

    -- ===== ACT =====
    ---@type AdapterExecutionResult
    local got = integration.execute_adapter_direct(position_id)

    -- Expected complete adapter execution result
    -- Based on the actual test output, the adapter does detect subtests in the results
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
          status = "failed",
          errors = {},
        },
        -- Individual test results
        [position_id .. "::TestPassing"] = {
          status = "passed",
          errors = {},
        },
        [position_id .. "::TestFailing"] = {
          status = "failed",
          errors = {
            {
              message = "this test intentionally fails",
              line = 13,
              severity = vim.diagnostic.severity.HINT,
            },
          },
        },
        [position_id .. "::TestSkipped"] = {
          status = "skipped",
          errors = {
            {
              message = "this test is intentionally skipped",
              line = 18,
              severity = vim.diagnostic.severity.HINT,
            },
          },
        },
        [position_id .. "::TestWithFailingSubtest"] = {
          status = "failed",
          errors = {},
        },
        [position_id .. "::TestWithSkippedSubtest"] = {
          status = "passed",
          errors = {},
        },
        -- Subtest results
        [position_id .. '::TestWithFailingSubtest::"SubtestPassing"'] = {
          status = "passed",
          errors = {},
        },
        [position_id .. '::TestWithFailingSubtest::"SubtestFailing"'] = {
          status = "failed",
          errors = {
            {
              message = "this subtest intentionally fails",
              line = 28,
              severity = vim.diagnostic.severity.HINT,
            },
          },
        },
        [position_id .. '::TestWithSkippedSubtest::"SubtestPassing"'] = {
          status = "passed",
          errors = {},
        },
        [position_id .. '::TestWithSkippedSubtest::"SubtestSkipped"'] = {
          status = "skipped",
          errors = {
            {
              message = "this subtest is intentionally skipped",
              line = 39,
              severity = vim.diagnostic.severity.HINT,
            },
          },
        },
      },
      run_spec = {
        context = {
          pos_id = position_id,
        },
      },
      strategy_result = {
        code = 1,
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
  end)
end)
