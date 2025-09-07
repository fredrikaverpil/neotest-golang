local _ = require("plenary")
local options = require("neotest-golang.options")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/tests/helpers/integration.lua"
local integration = dofile(integration_path)

-- Load assertion helpers
local assert_helpers = dofile(vim.uv.cwd() .. "/tests/helpers/assert.lua")

describe("Integration: diagnostics test", function()
  it(
    "file reports test discovery and execution for diagnostic classification",
    function()
      -- ===== ARRANGE =====
      ---@type NeotestGolangOptions
      local test_options =
        { runner = "gotestsum", warn_test_results_missing = false }
      options.set(test_options)

      local test_filepath = vim.uv.cwd()
        .. "/tests/go/internal/diagnostics/diagnostics_test.go"
      test_filepath = integration.normalize_path(test_filepath)

      -- ===== ACT =====
      ---@type AdapterExecutionResult
      local got = integration.execute_adapter_direct(test_filepath)

      -- Expected complete adapter execution result
      -- Note: The skipped tests are expected to pass since they're skipped
      ---@type AdapterExecutionResult
      local want = {
        results = {
          -- Directory-level result (created by file aggregation)
          [vim.fs.dirname(test_filepath)] = {
            status = "passed",
            errors = {
              {
                message = "I'm a logging hint message",
                line = 11,
                severity = vim.diagnostic.severity.HINT,
              },
            },
          },
          -- File-level result
          [test_filepath] = {
            status = "passed",
            errors = {},
          },
          -- Individual test results
          [test_filepath .. "::TestDiagnostics"] = {
            status = "passed",
            errors = {},
          },
          [test_filepath .. "::TestDiagnosticsTopLevelLog"] = {
            status = "passed",
            errors = {
              {
                message = "top-level hint: this should be classified as a hint",
                line = 18,
                severity = vim.diagnostic.severity.HINT,
              },
            },
          },
          [test_filepath .. "::TestDiagnosticsTopLevelError"] = {
            status = "skipped",
            errors = {
              {
                message = "remove skip to trigger error",
                line = 24,
                severity = vim.diagnostic.severity.HINT,
              },
            },
          },
          [test_filepath .. "::TestDiagnosticsTopLevelPanic"] = {
            status = "skipped",
            errors = {
              {
                message = "remove skip to trigger panic",
                line = 31,
                severity = vim.diagnostic.severity.HINT,
              },
            },
          },
          -- Subtest results
          [test_filepath .. '::TestDiagnostics::"log"'] = {
            status = "passed",
            errors = {
              {
                message = "I'm a logging hint message",
                line = 11,
                severity = vim.diagnostic.severity.HINT,
              },
            },
          },
        },
        run_spec = {
          context = {
            pos_id = test_filepath,
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
