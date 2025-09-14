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
      ---@type NeotestGolangOptions
      local test_options = { runner = "gotestsum" }
      options.set(test_options)

      local test_dirpath = vim.uv.cwd() .. "/tests/go/internal/multifile"
      test_dirpath = integration.normalize_path(test_dirpath)

      -- Build expected file paths
      local first_file_path = test_dirpath .. "/first_file_test.go"
      local second_file_path = test_dirpath .. "/second_file_test.go"
      first_file_path = integration.normalize_path(first_file_path)
      second_file_path = integration.normalize_path(second_file_path)

      ---@type AdapterExecutionResult
      local want = {
        results = {
          -- Directory-level result
          [test_dirpath] = {
            status = "passed",
            errors = {},
          },
          -- File-level results
          [first_file_path] = {
            status = "passed",
            errors = {},
          },
          [second_file_path] = {
            status = "passed",
            errors = {},
          },
          -- Individual test results
          [first_file_path .. "::TestOne"] = {
            status = "passed",
            errors = {},
          },
          [second_file_path .. "::TestTwo"] = {
            status = "passed",
            errors = {},
          },
        },
        run_spec = {
          command = {}, -- this will be replaced in the assertion
          context = {
            pos_id = test_dirpath,
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
      -- Use the new execute_adapter_direct_dir function to test the entire directory
      -- This should run all tests in the multifile package (TestOne from first_file_test.go, TestTwo from second_file_test.go)
      ---@type AdapterExecutionResult
      local got = integration.execute_adapter_direct_dir(test_dirpath)

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

      -- Copy dynamic fields for all results
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

