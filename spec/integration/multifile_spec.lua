local _ = require("plenary")
local options = require("neotest-golang.options")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Integration: multifile test", function()
  it(
    "directory testing runs both TestOne and TestTwo from multiple files",
    function()
      -- ===== ARRANGE =====
      local test_options = options.get()
      test_options.runner = "gotestsum"
      options.set(test_options)

      local pos_id_dir = vim.uv.cwd() .. "/tests/go/internal/multifile"
      pos_id_dir = integration.normalize_path(pos_id_dir)

      local pos_id_first = pos_id_dir .. "/first_file_test.go"
      local pos_id_second = pos_id_dir .. "/second_file_test.go"
      pos_id_first = integration.normalize_path(pos_id_first)
      pos_id_second = integration.normalize_path(pos_id_second)

      ---@type AdapterExecutionResult
      local want = {
        results = {
          -- Parent directory result
          [vim.fs.dirname(pos_id_dir)] = {
            status = "passed",
            errors = {},
          },
          -- Directory-level result
          [pos_id_dir] = {
            status = "passed",
            errors = {},
          },
          -- File-level results
          [pos_id_first] = {
            status = "passed",
            errors = {},
          },
          [pos_id_second] = {
            status = "passed",
            errors = {},
          },
          -- Individual test results
          [pos_id_first .. "::TestOne"] = {
            status = "passed",
            errors = {},
          },
          [pos_id_second .. "::TestTwo"] = {
            status = "passed",
            errors = {},
          },
        },
        run_spec = {
          command = {}, -- this will be replaced in the assertion
          context = {
            pos_id = pos_id_dir,
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
      local got = integration.execute_adapter_direct(pos_id_dir)

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
      want.run_spec.context.runner_exec_context =
        got.run_spec.context.runner_exec_context
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

      assert.are.same(vim.inspect(want), vim.inspect(got))
    end
  )
end)
