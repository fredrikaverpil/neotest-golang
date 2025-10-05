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

      local position_id = vim.uv.cwd() .. "/tests/go"
      position_id = path.normalize_path(position_id)

      ---@type AdapterExecutionResult
      -- FIXME: should we not see positions for all the individual _test.go files inside the `want`?
      -- Wea re only seeing dir positions and no file or test positions.
      local want = {
        results = {
          ["/Users/fredrik/code/public/neotest-golang/tests/go"] = {
            errors = {},
            status = "failed",
          },
          ["/Users/fredrik/code/public/neotest-golang/tests/go/cmd"] = {
            errors = {},
            status = "skipped",
          },
          ["/Users/fredrik/code/public/neotest-golang/tests/go/cmd/main"] = {
            errors = {},
            status = "skipped",
          },
          ["/Users/fredrik/code/public/neotest-golang/tests/go/internal"] = {
            errors = {
              -- FIXME: this seems wrong, we are missing diagnostics_test.go errors
              {
                line = 9,
                message = "hello world",
                severity = 4,
              },
              {
                line = 10,
                message = "whuat",
                severity = 4,
              },
              {
                line = 13,
                message = "top-level hint: this should be classified as a hint",
                severity = 4,
              },
              {
                line = 16,
                message = "goodbye world",
                severity = 4,
              },
            },
            status = "failed",
          },
          ["/Users/fredrik/code/public/neotest-golang/tests/go/internal/diagnostics"] = {
            errors = {
              -- FIXME: this is wrong, we should have more tests and failing ones too. See diatnostics_spec.lua.
              {
                line = 13,
                message = "top-level hint: this should be classified as a hint",
                severity = 4,
              },
            },
            status = "passed", -- FIXME: this is wrong, as tests below are failing
          },
          ["/Users/fredrik/code/public/neotest-golang/tests/go/internal/dupes"] = {
            errors = {},
            status = "passed",
          },
          ["/Users/fredrik/code/public/neotest-golang/tests/go/internal/multifile"] = {
            errors = {},
            status = "passed",
          },
          ["/Users/fredrik/code/public/neotest-golang/tests/go/internal/nested"] = {
            errors = {},
            status = "passed",
          },
          ["/Users/fredrik/code/public/neotest-golang/tests/go/internal/nested/subpackage2"] = {
            errors = {},
            status = "passed",
          },
          ["/Users/fredrik/code/public/neotest-golang/tests/go/internal/nested/subpackage2/subpackage3"] = {
            errors = {},
            status = "passed",
          },
          ["/Users/fredrik/code/public/neotest-golang/tests/go/internal/notests"] = {
            errors = {},
            status = "skipped",
          },
          ["/Users/fredrik/code/public/neotest-golang/tests/go/internal/packaging"] = {
            errors = {},
            status = "passed",
          },
          ["/Users/fredrik/code/public/neotest-golang/tests/go/internal/positions"] = {
            errors = {},
            status = "passed",
          },
          ["/Users/fredrik/code/public/neotest-golang/tests/go/internal/precision"] = {
            errors = {},
            status = "passed",
          },
          ["/Users/fredrik/code/public/neotest-golang/tests/go/internal/query_duplicates"] = {
            errors = {},
            status = "passed",
          },
          ["/Users/fredrik/code/public/neotest-golang/tests/go/internal/singletest"] = {
            errors = {},
            status = "passed",
          },
          ["/Users/fredrik/code/public/neotest-golang/tests/go/internal/specialchars"] = {
            errors = {},
            status = "passed",
          },
          ["/Users/fredrik/code/public/neotest-golang/tests/go/internal/testifysuites"] = {
            errors = {
              {
                line = 9,
                message = "hello world",
                severity = 4,
              },
              {
                line = 10,
                message = "whuat",
                severity = 4,
              },
              {
                line = 16,
                message = "goodbye world",
                severity = 4,
              },
            },
            status = "failed",
          },
          ["/Users/fredrik/code/public/neotest-golang/tests/go/internal/teststates"] = {
            errors = {},
            status = "passed",
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
