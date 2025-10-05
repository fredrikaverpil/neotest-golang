local _ = require("plenary")
local options = require("neotest-golang.options")
local path = require("neotest-golang.lib.path")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Integration: diagnostics test", function()
  it(
    "file reports test discovery and execution for diagnostic classification",
    function()
      -- ===== ARRANGE =====
      local test_options = options.get()
      test_options.runner = "gotestsum"
      options.set(test_options)

      local position_id = vim.uv.cwd() .. "/tests/go/internal/diagnostics"
      position_id = path.normalize_path(position_id)

      ---@type AdapterExecutionResult
      local want = {
        results = {
          -- Parent directory result (created by hierarchical aggregation)
          [path.normalize_path(vim.uv.cwd() .. "/tests/go/internal")] = {
            status = "failed", -- Now properly aggregates failed status from subdirectories
            errors = {
              {
                message = "top-level hint: this should be classified as a hint",
                line = 13,
                severity = 4,
              },
              {
                message = "expected 42 but got 0",
                line = 17,
                severity = 1,
              },
              {
                message = "not implemented yet",
                line = 21,
                severity = 4,
              },
              {
                message = "I'm a logging hint message",
                line = 26,
                severity = 4,
              },
              {
                message = "I'm an error message",
                line = 30,
                severity = 4,
              },
              {
                message = "I'm a skip message",
                line = 34,
                severity = 4,
              },
              {
                message = "assertion failed: ",
                line = 40,
                severity = 1,
              },
            },
          },
          -- Current directory result (contains all aggregated test results)
          [position_id] = {
            status = "failed",
            errors = {
              {
                message = "top-level hint: this should be classified as a hint",
                line = 13,
                severity = 4,
              },
              {
                message = "expected 42 but got 0",
                line = 17,
                severity = 1,
              },
              {
                message = "not implemented yet",
                line = 21,
                severity = 4,
              },
              {
                message = "I'm a logging hint message",
                line = 26,
                severity = 4,
              },
              {
                message = "I'm an error message",
                line = 30,
                severity = 4,
              },
              {
                message = "I'm a skip message",
                line = 34,
                severity = 4,
              },
              {
                message = "assertion failed: ",
                line = 40,
                severity = 1,
              },
            },
          },
          -- File-level result (gets aggregated errors from child tests)
          [path.normalize_path(
            vim.uv.cwd() .. "/tests/go/internal/diagnostics/diagnostics_test.go"
          )] = {
            status = "failed",
            errors = {
              {
                message = "top-level hint: this should be classified as a hint",
                line = 13,
                severity = 4,
              },
              {
                message = "expected 42 but got 0",
                line = 17,
                severity = 1,
              },
              {
                message = "not implemented yet",
                line = 21,
                severity = 4,
              },
              {
                message = "I'm a logging hint message",
                line = 26,
                severity = 4,
              },
              {
                message = "I'm an error message",
                line = 30,
                severity = 4,
              },
              {
                message = "I'm a skip message",
                line = 34,
                severity = 4,
              },
              {
                message = "assertion failed: ",
                line = 40,
                severity = 1,
              },
            },
          },
          -- Individual test results
          [path.normalize_path(
            vim.uv.cwd() .. "/tests/go/internal/diagnostics/diagnostics_test.go"
          ) .. "::TestDiagnosticsTopLevelLog"] = {
            status = "passed",
            errors = {
              {
                message = "top-level hint: this should be classified as a hint",
                line = 13,
                severity = 4,
              },
            },
          },
          [path.normalize_path(
            vim.uv.cwd() .. "/tests/go/internal/diagnostics/diagnostics_test.go"
          ) .. "::TestDiagnosticsTopLevelError"] = {
            status = "failed",
            errors = {
              {
                message = "expected 42 but got 0",
                line = 17,
                severity = 1,
              },
            },
          },
          [path.normalize_path(
            vim.uv.cwd() .. "/tests/go/internal/diagnostics/diagnostics_test.go"
          ) .. "::TestDiagnosticsTopLevelSkip"] = {
            status = "skipped",
            errors = {
              {
                message = "not implemented yet",
                line = 21,
                severity = 4,
              },
            },
          },
          [path.normalize_path(
            vim.uv.cwd() .. "/tests/go/internal/diagnostics/diagnostics_test.go"
          ) .. "::TestDiagnosticsSubTests"] = {
            errors = {},
            status = "failed",
          },
          [path.normalize_path(
            vim.uv.cwd() .. "/tests/go/internal/diagnostics/diagnostics_test.go"
          ) .. '::TestDiagnosticsSubTests::"log"'] = {
            errors = {
              {
                line = 26,
                message = "I'm a logging hint message",
                severity = 4,
              },
            },
            status = "passed",
          },
          [path.normalize_path(
            vim.uv.cwd() .. "/tests/go/internal/diagnostics/diagnostics_test.go"
          ) .. '::TestDiagnosticsSubTests::"error"'] = {
            errors = {
              {
                line = 30,
                message = "I'm an error message",
                severity = 4,
              },
            },
            status = "failed",
          },
          [path.normalize_path(
            vim.uv.cwd() .. "/tests/go/internal/diagnostics/diagnostics_test.go"
          ) .. '::TestDiagnosticsSubTests::"skip"'] = {
            errors = {
              {
                line = 34,
                message = "I'm a skip message",
                severity = 4,
              },
            },
            status = "skipped",
          },
          [path.normalize_path(
            vim.uv.cwd() .. "/tests/go/internal/diagnostics/diagnostics_test.go"
          ) .. "::TestAssertV3"] = {
            status = "failed",
            errors = {},
          },
          [path.normalize_path(
            vim.uv.cwd() .. "/tests/go/internal/diagnostics/diagnostics_test.go"
          ) .. '::TestAssertV3::"deep equal"'] = {
            status = "failed",
            errors = {
              {
                message = "assertion failed: ",
                line = 40,
                severity = 1,
              },
            },
          },
        },
        run_spec = {
          command = {}, -- this will be replaced in the assertion
          context = {
            pos_id = position_id,
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
      local got = integration.execute_adapter_direct(position_id)

      -- ===== ASSERT =====
      want.tree = got.tree
      want.run_spec.cwd = got.run_spec.cwd
      want.run_spec.command = got.run_spec.command
      want.run_spec.env = got.run_spec.env
      want.run_spec.stream = got.run_spec.stream
      want.run_spec.strategy = got.run_spec.strategy
      want.run_spec.context.golist_data = got.run_spec.context.golist_data
      want.run_spec.context.stop_filestream =
        got.run_spec.context.stop_filestream
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

      -- Sort errors for order-agnostic comparison
      -- Helper function to sort errors for order-agnostic comparison
      local function sort_errors(errors)
        if not errors or #errors == 0 then
          return errors or {}
        end
        local sorted = vim.deepcopy(errors)
        table.sort(sorted, function(a, b)
          if a.line ~= b.line then
            return a.line < b.line
          end
          return a.message < b.message
        end)
        return sorted
      end

      -- Sort errors in both expected and actual results for order-agnostic comparison
      for pos_id, result in pairs(want.results) do
        if result.errors then
          result.errors = sort_errors(result.errors)
        end
      end
      for pos_id, result in pairs(got.results) do
        if result.errors then
          result.errors = sort_errors(result.errors)
        end
      end

      assert.are.same(vim.inspect(want), vim.inspect(got))
    end
  )
end)
