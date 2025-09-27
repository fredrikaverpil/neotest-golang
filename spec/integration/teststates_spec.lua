local _ = require("plenary")
local options = require("neotest-golang.options")
local path = require("neotest-golang.lib.path")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Integration: test states", function()
  it(
    "file reports test discovery and execution for various test states (passing, failing, skipping)",
    function()
      -- ===== ARRANGE =====
      local test_options = options.get()
      test_options.runner = "gotestsum"
      options.set(test_options)

      local position_id = vim.uv.cwd()
        .. "/tests/go/internal/teststates/teststates_test.go"
      position_id = path.normalize_path(position_id)

      -- Expected complete adapter execution result
      ---@type AdapterExecutionResult
      local want = {
        results = {
          -- Parent directory result (created by hierarchical aggregation)
          [vim.uv.cwd() .. path.os_path_sep .. "tests" .. path.os_path_sep .. "go" .. path.os_path_sep .. "internal"] = {
            status = "passed",
            errors = {},
          },
          -- Directory-level result (created by file aggregation)
          [path.get_directory(position_id)] = {
            status = "passed",
            errors = {},
          },
          -- File-level result
          [position_id] = {
            status = "failed",
            errors = {
              {
                line = 18,
                message = "this test intentionally fails",
                severity = 4,
              },
              {
                line = 23,
                message = "this test is intentionally skipped",
                severity = 4,
              },
              {
                line = 28,
                message = "this test is also intentionally skipped",
                severity = 4,
              },
              {
                line = 38,
                message = "this subtest intentionally fails",
                severity = 4,
              },
              {
                line = 49,
                message = "this subtest is intentionally skipped",
                severity = 4,
              },
            },
          },
          -- Individual test results
          [position_id .. "::TestPassing"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestAlsoPassing"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestFailing"] = {
            status = "failed",
            errors = {
              {
                message = "this test intentionally fails",
                line = 18,
                severity = 4,
              },
            },
          },
          [position_id .. "::TestSkipped"] = {
            status = "skipped",
            errors = {
              {
                message = "this test is intentionally skipped",
                line = 23,
                severity = 4,
              },
            },
          },
          [position_id .. "::TestAlsoSkipped"] = {
            status = "skipped",
            errors = {
              {
                message = "this test is also intentionally skipped",
                line = 28,
                severity = 4,
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
                line = 38,
                severity = 4,
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
                line = 49,
                severity = 4,
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
          code = 1, -- Non-zero exit code due to failing tests
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
      local got = integration.execute_adapter_direct(
        position_id,
        { use_streaming = true }
      )

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

      assert.are.same(
        vim.inspect(want),
        vim.inspect(got),
        "Complete adapter execution result should match"
      )
    end
  )
end)
