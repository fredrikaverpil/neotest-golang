local _ = require("plenary")
local options = require("neotest-golang.options")
local path = require("neotest-golang.lib.path")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Integration: testify suites diagnostics", function()
  it(
    "TestHints: mixed t.Log, t.Error and assert with/without Messages",
    function()
      -- ===== ARRANGE =====
      local test_options = options.get()
      test_options.runner = "gotestsum"
      test_options.testify_enabled = true
      test_options.log_level = vim.log.levels.DEBUG
      options.set(test_options)

      local position_id = vim.uv.cwd()
        .. "/tests/features/internal/testifysuites/diagnostics_test.go"
      position_id = path.normalize_path(position_id)

      -- Expected errors for each test
      local test_hints_errors = {
        { line = 10, message = "hello world", severity = 4 }, -- t.Log
        { line = 11, message = "whuat", severity = 4 }, -- t.Error
        { line = 14, message = "Should be false", severity = 1 }, -- assert.False without message
        { line = 16, message = "Should be false: not shown", severity = 1 }, -- assert.Falsef with message
        { line = 18, message = "goodbye world", severity = 4 }, -- t.Log
      }

      local test_consecutive_failures_errors = {
        { line = 24, message = "Not equal:", severity = 1 },
        { line = 26, message = "Should be true", severity = 1 },
        {
          line = 28,
          message = '"hello" does not contain "x": expected x in string',
          severity = 1,
        },
      }

      local test_mixed_assert_types_errors = {
        { line = 33, message = "starting mixed test", severity = 4 },
        {
          line = 36,
          message = "Not equal:: values should match",
          severity = 1,
        },
        { line = 38, message = "manual error in between", severity = 4 },
        {
          line = 41,
          message = "[]int{1, 2, 3} does not contain 5: slice should contain 5",
          severity = 1,
        },
        {
          line = 44,
          message = "Expected value not to be nil.: should not be nil",
          severity = 1,
        },
      }

      -- File-level errors aggregate all test errors
      -- Note: Order doesn't matter because we sort before comparison
      local file_level_errors = {}
      vim.list_extend(file_level_errors, test_hints_errors)
      vim.list_extend(file_level_errors, test_consecutive_failures_errors)
      vim.list_extend(file_level_errors, test_mixed_assert_types_errors)

      -- Expected complete adapter execution result
      ---@type AdapterExecutionResult
      local want = {
        results = {
          -- Package-level result (from streaming) - no errors as streaming doesn't extract them
          [path.get_directory(position_id)] = {
            status = "failed",
            errors = {},
          },
          -- File-level result
          [position_id] = {
            status = "failed",
            errors = file_level_errors,
          },
          -- Test results for all three tests in the file
          [position_id .. "::TestHints"] = {
            status = "failed",
            errors = test_hints_errors,
          },
          [position_id .. "::TestConsecutiveFailures"] = {
            status = "failed",
            errors = test_consecutive_failures_errors,
          },
          [position_id .. "::TestMixedAssertTypes"] = {
            status = "failed",
            errors = test_mixed_assert_types_errors,
          },
        },
        run_spec = {
          command = {}, -- this will be replaced in the assertion
          context = {
            pos_id = position_id,
          },
        },
        strategy_result = {
          code = 1, -- Test should fail
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
      -- Deep-copy the result so we can safely mutate for the assertion
      local got_copy = vim.deepcopy(got)

      -- ===== ASSERT =====
      -- Copy dynamic run_spec fields onto the copy
      want.run_spec.command = got_copy.run_spec.command
      want.run_spec.cwd = got_copy.run_spec.cwd
      want.run_spec.env = got_copy.run_spec.env
      want.run_spec.stream = got_copy.run_spec.stream
      want.run_spec.strategy = got_copy.run_spec.strategy
      want.run_spec.context.golist_data = got_copy.run_spec.context.golist_data
      want.run_spec.context.stop_filestream =
        got_copy.run_spec.context.stop_filestream
      want.run_spec.context.test_output_json_filepath =
        got_copy.run_spec.context.test_output_json_filepath
      want.strategy_result.output = got_copy.strategy_result.output
      want.tree = got_copy.tree
      for pos_id, result in pairs(got_copy.results) do
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
      for pos_id, result in pairs(got_copy.results) do
        if result.errors then
          result.errors = sort_errors(result.errors)
        end
      end

      assert.are.same(
        want,
        got_copy,
        "Complete adapter execution result should match"
      )
    end
  )
end)
