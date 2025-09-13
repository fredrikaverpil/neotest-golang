local _ = require("plenary")
local options = require("neotest-golang.options")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/tests/helpers/integration.lua"
local integration = dofile(integration_path)


describe("Integration: special characters test", function()
  it(
    "file reports test discovery and execution for tests with special characters",
    function()
      -- ===== ARRANGE =====
      ---@type NeotestGolangOptions
      local test_options =
        { runner = "gotestsum", warn_test_results_missing = false }
      options.set(test_options)

      local test_filepath = vim.uv.cwd()
        .. "/tests/go/internal/specialchars/special_characters_test.go"
      test_filepath = integration.normalize_path(test_filepath)

      -- ===== ACT =====
      ---@type AdapterExecutionResult
      local got = integration.execute_adapter_direct(test_filepath)

      -- Expected complete adapter execution result
      ---@type AdapterExecutionResult
      local want = {
        results = {
          -- Directory-level result (created by file aggregation)
          [vim.fs.dirname(test_filepath)] = {
            status = "passed",
            errors = {},
          },
          -- File-level result
          [test_filepath] = {
            status = "passed",
            errors = {},
          },
          -- Individual test results
          [test_filepath .. "::TestNames"] = {
            status = "passed",
            errors = {},
          },
          -- Subtest results with special characters
          [test_filepath .. '::TestNames::"Mixed case with space"'] = {
            status = "passed",
            errors = {},
          },
          [test_filepath .. '::TestNames::"Period . comma , and apostrophy \' are ok to use"'] = {
            status = "passed",
            errors = {},
          },
          [test_filepath .. '::TestNames::"Brackets [1] (2) {3} are ok"'] = {
            status = "passed",
            errors = {},
          },
          [test_filepath .. '::TestNames::"Percentage sign like 50% is ok"'] = {
            status = "passed",
            errors = {},
          },
          [test_filepath .. '::TestNames::"Test(success)"'] = {
            status = "passed",
            errors = {},
          },
          [test_filepath .. '::TestNames::"Regexp characters like ( ) [ ] { } - | ? + * ^ $ are ok"'] = {
            status = "passed",
            errors = {},
          },
          [test_filepath .. '::TestNames::"nested1"'] = {
            status = "passed",
            errors = {},
          },
          -- Nested subtest results
          [test_filepath .. '::TestNames::"nested1"::"nested2"'] = {
            status = "passed",
            errors = {},
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
