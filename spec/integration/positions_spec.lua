local _ = require("plenary")
local options = require("neotest-golang.options")
local path = require("neotest-golang.lib.path")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Integration: positions test", function()
  it(
    "file reports test discovery and execution for various test names and positions",
    function()
      -- ===== ARRANGE =====
      local test_options = options.get()
      test_options.runner = "gotestsum"
      options.set(test_options)

      local position_id = vim.uv.cwd()
        .. "/tests/go/internal/positions/positions_test.go"
      position_id = path.normalize_path(position_id)

      -- ===== ACT =====
      print("\n[TEST] Running positions test with ASYNC execution...")
      ---@type AdapterExecutionResult
      local got = integration.execute_adapter_direct(position_id, true) -- ASYNC EXECUTION

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
            status = "passed",
            errors = {},
          },
          -- Individual test results
          [position_id .. "::TestTopLevel"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestTopLevelWithSubTest"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestTableTestStruct"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestSubTestTableTestStruct"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestTableTestInlineStruct"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestSubTestTableTestInlineStruct"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestTableTestInlineStructLoop"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestTableTestInlineStructLoopNotKeyed"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestTableTestInlineStructLoopNotKeyed2"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestSubTestTableTestInlineStructLoop"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestTableTestMap"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestTableTestInlineCompositeWithFieldAccess"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestStructNotTableTest"] = {
            status = "passed",
            errors = {},
          },
          -- Subtest results
          [position_id .. '::TestTopLevelWithSubTest::"SubTest"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestTableTestStruct::"TableTest1"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestTableTestStruct::"TableTest2"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestSubTestTableTestStruct::"SubTest"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestSubTestTableTestStruct::"SubTest"::"TableTest1"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestSubTestTableTestStruct::"SubTest"::"TableTest2"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestTableTestInlineStruct::"TableTest1"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestTableTestInlineStruct::"TableTest2"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestSubTestTableTestInlineStruct::"SubTest"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestSubTestTableTestInlineStruct::"SubTest"::"TableTest1"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestSubTestTableTestInlineStruct::"SubTest"::"TableTest2"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestTableTestInlineStructLoop::"TableTest1"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestTableTestInlineStructLoop::"TableTest2"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestTableTestInlineStructLoopNotKeyed::"TableTest1"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestTableTestInlineStructLoopNotKeyed::"TableTest2"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestTableTestInlineStructLoopNotKeyed2::"TableTest1"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestTableTestInlineStructLoopNotKeyed2::"TableTest2"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestSubTestTableTestInlineStructLoop::"SubTest"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestSubTestTableTestInlineStructLoop::"SubTest"::"TableTest1"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestSubTestTableTestInlineStructLoop::"SubTest"::"TableTest2"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestTableTestMap::"TableTest1"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestTableTestMap::"TableTest2"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestTableTestInlineCompositeWithFieldAccess::"user1"'] = {
            status = "passed",
            errors = {},
          },
          [position_id .. '::TestTableTestInlineCompositeWithFieldAccess::"user2"'] = {
            status = "passed",
            errors = {},
          },
        },
        run_spec = {
          command = {}, -- this will be replaced in the assertion
          context = {
            pos_id = position_id,
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

      assert.are.same(
        vim.inspect(want),
        vim.inspect(got),
        "Complete adapter execution result should match"
      )
    end
  )
end)
