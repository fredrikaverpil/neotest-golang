local _ = require("plenary")
local find = require("neotest-golang.lib.find")
local options = require("neotest-golang.options")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
local integration = dofile(integration_path)
local utils_path = vim.uv.cwd() .. "/spec/helpers/utils.lua"
local utils = dofile(utils_path)

describe("Integration: diagnostics test", function()
  it(
    "file reports test discovery and execution for diagnostic classification",
    function()
      -- ===== ARRANGE =====
      local test_options = options.get()
      test_options.runner = "gotestsum"
      options.set(test_options)

      local position_id = vim.uv.cwd()
        .. "/tests/go/internal/diagnostics/diagnostics_test.go"
      position_id = integration.normalize_path(position_id)

      ---@type AdapterExecutionResult
      local want = {
        results = {
          -- Parent directory result (created by hierarchical aggregation)
          [utils.normalize_path(vim.uv.cwd() .. "/tests/go/internal")] = {
            status = "passed",
            errors = {
              {
                message = "top-level hint: this should be classified as a hint",
                line = 9, -- 0-indexed: line 10 - 1
                severity = 4, -- vim.diagnostic.severity.HINT
              },
            },
          },
          -- Directory-level result (created by file aggregation)
          [find.get_directory(position_id)] = {
            status = "passed", -- Directory shows passed due to aggregation logic
            errors = {
              {
                message = "top-level hint: this should be classified as a hint",
                line = 9, -- 0-indexed: line 10 - 1
                severity = 4, -- vim.diagnostic.severity.HINT
              },
            },
          },
          -- File-level result (gets aggregated errors from child tests)
          [position_id] = {
            status = "failed", -- File fails because some tests fail
            errors = {
              {
                message = "I'm an error message",
                line = 26,
                severity = 4,
              },
              {
                message = "I'm a logging hint message",
                line = 22,
                severity = 4,
              },
              {
                message = "I'm a skip message",
                line = 30,
                severity = 4,
              },
              {
                message = "top-level hint: this should be classified as a hint",
                line = 9, -- 0-indexed: line 10 - 1
                severity = 4, -- vim.diagnostic.severity.HINT
              },
              {
                message = "expected 42 but got 0",
                line = 13, -- 0-indexed: line 14 - 1
                severity = 1, -- vim.diagnostic.severity.ERROR
              },
              {
                message = "not implemented yet",
                line = 17, -- 0-indexed: line 18 - 1
                severity = 4, -- vim.diagnostic.severity.HINT
              },
            },
          },
          -- Individual test results
          [position_id .. "::TestDiagnosticsTopLevelLog"] = {
            status = "passed",
            errors = {
              {
                message = "top-level hint: this should be classified as a hint",
                line = 9, -- 0-indexed: line 10 - 1
                severity = 4, -- vim.diagnostic.severity.HINT
              },
            },
          },
          [position_id .. "::TestDiagnosticsTopLevelError"] = {
            status = "failed",
            errors = {
              {
                message = "expected 42 but got 0",
                line = 13, -- 0-indexed: line 14 - 1
                severity = 1, -- vim.diagnostic.severity.ERROR
              },
            },
          },
          [position_id .. "::TestDiagnosticsTopLevelSkip"] = {
            status = "skipped",
            errors = {
              {
                message = "not implemented yet",
                line = 17, -- 0-indexed: line 18 - 1
                severity = 4, -- vim.diagnostic.severity.HINT
              },
            },
          },
          [position_id .. "::TestDiagnosticsSubTests"] = {
            errors = {},
            status = "failed",
          },
          [position_id .. '::TestDiagnosticsSubTests::"error"'] = {
            errors = {
              {
                line = 26,
                message = "I'm an error message",
                severity = 4,
              },
            },
            status = "failed",
          },
          [position_id .. '::TestDiagnosticsSubTests::"log"'] = {
            errors = {
              {
                line = 22,
                message = "I'm a logging hint message",
                severity = 4,
              },
            },
            status = "passed",
          },
          [position_id .. '::TestDiagnosticsSubTests::"skip"'] = {
            errors = {
              {
                line = 30,
                message = "I'm a skip message",
                severity = 4,
              },
            },
            status = "skipped",
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
