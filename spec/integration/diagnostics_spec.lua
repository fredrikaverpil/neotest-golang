local _ = require("plenary")
local options = require("neotest-golang.options")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Integration: diagnostics test", function()
  it(
    "file reports test discovery and execution for diagnostic classification",
    function()
      -- ===== ARRANGE =====
      ---@type NeotestGolangOptions
      local test_options = { runner = "gotestsum" }
      options.set(test_options)

      local test_filepath = vim.uv.cwd()
        .. "/tests/go/internal/diagnostics/diagnostics_test.go"
      test_filepath = integration.normalize_path(test_filepath)

      ---@type AdapterExecutionResult
      local want = {
        results = {
          -- Directory-level result (created by file aggregation)
          [vim.fs.dirname(test_filepath)] = {
            status = "passed", -- Directory shows passed due to aggregation logic
            errors = {
              {
                message = "top-level hint: this should be classified as a hint",
                line = 9, -- 0-indexed: line 10 - 1
                severity = 4, -- vim.diagnostic.severity.HINT
              },
            },
          },
          -- File-level result
          [test_filepath] = {
            status = "failed", -- File fails because some tests fail
            errors = {},
          },
          -- Individual test results
          [test_filepath .. "::TestDiagnosticsTopLevelLog"] = {
            status = "passed",
            errors = {
              {
                message = "top-level hint: this should be classified as a hint",
                line = 9, -- 0-indexed: line 10 - 1
                severity = 4, -- vim.diagnostic.severity.HINT
              },
            },
          },
          [test_filepath .. "::TestDiagnosticsTopLevelError"] = {
            status = "failed",
            errors = {
              {
                message = "expected 42 but got 0",
                line = 13, -- 0-indexed: line 14 - 1
                severity = 1, -- vim.diagnostic.severity.ERROR
              },
            },
          },
          [test_filepath .. "::TestDiagnosticsTopLevelSkip"] = {
            status = "skipped",
            errors = {
              {
                message = "not implemented yet",
                line = 17, -- 0-indexed: line 18 - 1
                severity = 4, -- vim.diagnostic.severity.HINT
              },
            },
          },
          [test_filepath .. "::TestDiagnosticsTopLevelPanic"] = {
            status = "failed",
            errors = {}, -- Panic has complex stack trace, keep empty
          },
        },
        run_spec = {
          command = {}, -- this will be replaced in the assertion
          context = {
            pos_id = test_filepath,
          },
        },
        strategy_result = {
          code = 1,
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
      local got = integration.execute_adapter_direct(test_filepath)

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
