local _ = require("plenary")
local options = require("neotest-golang.options")
local path = require("neotest-golang.lib.path")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Integration: testify suites diagnostics test", function()
  it(
    "file reports testify assertion errors with actual error messages",
    function()
      -- ===== ARRANGE =====
      local test_options = options.get()
      test_options.runner = "gotestsum"
      test_options.testify_enabled = true
      test_options.log_level = vim.log.levels.DEBUG
      options.set(test_options)

      local position_id = vim.uv.cwd()
        .. "/tests/go/internal/testifysuites/hints_test.go"
      position_id = path.normalize_path(position_id)

      -- Reuse a single canonical error list to avoid repetition
      local common_errors = {
        { line = 9, message = "hello world", severity = 4 },
        { line = 10, message = "whuat", severity = 4 },
        { line = 13, message = "Should be false", severity = 1 },
        { line = 14, message = "Should be false", severity = 1 },
        { line = 16, message = "goodbye world", severity = 4 },
      }

      -- Expected complete adapter execution result
      ---@type AdapterExecutionResult
      local want = {
        results = {
          -- Parent directory result
          [path.get_directory(path.get_directory(position_id))] = {
            status = "failed",
            errors = common_errors,
          },
          -- Directory-level result
          [path.get_directory(position_id)] = {
            status = "failed",
            errors = common_errors,
          },
          -- File-level result
          [position_id] = {
            status = "failed",
            errors = common_errors,
          },
          -- Test result
          [position_id .. "::TestHints"] = {
            status = "failed",
            errors = common_errors,
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

      assert.are.same(
        want,
        got_copy,
        "Complete adapter execution result should match"
      )
    end
  )
end)
