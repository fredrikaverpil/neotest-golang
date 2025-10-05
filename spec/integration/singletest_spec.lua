local _ = require("plenary")
local options = require("neotest-golang.options")
local path = require("neotest-golang.lib.path")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Integration: singletest test", function()
  it(
    "file reports test discovery and execution for simple individual tests",
    function()
      -- ===== ARRANGE =====
      local test_options = options.get()
      test_options.runner = "gotestsum"
      options.set(test_options)

      local position_id = vim.uv.cwd()
        .. "/tests/go/internal/singletest/singletest_test.go"
      position_id = path.normalize_path(position_id)

      -- Expected complete adapter execution result
      ---@type AdapterExecutionResult
      local want = {
        results = {
          -- Package-level result (from streaming)
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
          [position_id .. "::TestOne"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestTwo"] = {
            status = "passed",
            errors = {},
          },
          [position_id .. "::TestThree"] = {
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

      -- ===== ACT =====
      ---@type AdapterExecutionResult
      local got = integration.execute_adapter_direct(position_id)

      -- ===== ASSERT =====
      -- Copy dynamic fields from got to want for comparison
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
      want.run_spec.context.pos_id = got.run_spec.context.pos_id
      want.run_spec.context.process_test_results =
        got.run_spec.context.process_test_results
      want.strategy_result.output = got.strategy_result.output

      -- Copy output and short fields from got results to want results
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

  it("individual test execution runs only the specified test", function()
    -- ===== ARRANGE =====
    local test_options = options.get()
    test_options.runner = "gotestsum"
    options.set(test_options)

    local position_id_file = vim.uv.cwd()
      .. "/tests/go/internal/singletest/singletest_test.go"
    position_id_file = path.normalize_path(position_id_file)
    local position_id_test = position_id_file .. "::TestOne"

    -- Expected complete adapter execution result - only TestOne should run
    ---@type AdapterExecutionResult
    local want = {
      results = {
        -- Package-level result (from streaming)
        [path.get_directory(position_id_file)] = {
          status = "passed",
          errors = {},
        },
        -- File-level result
        [position_id_file] = {
          status = "passed",
          errors = {},
        },
        -- Individual test results - ONLY TestOne should be present!
        [position_id_test] = {
          status = "passed",
          errors = {},
        },
        -- TestTwo and TestThree should NOT be in the results since we're targeting only TestOne
      },
      run_spec = {
        command = {}, -- this will be replaced in the assertion
        context = {
          pos_id = position_id_test,
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
    local got = integration.execute_adapter_direct(position_id_test)

    -- ===== ASSERT =====

    -- Copy dynamic fields from got to want for comparison
    want.tree = got.tree
    want.run_spec.cwd = got.run_spec.cwd
    want.run_spec.command = got.run_spec.command
    want.run_spec.env = got.run_spec.env
    want.run_spec.stream = got.run_spec.stream
    want.run_spec.strategy = got.run_spec.strategy
    want.run_spec.context.golist_data = got.run_spec.context.golist_data
    want.run_spec.context.stop_filestream = got.run_spec.context.stop_filestream
    want.run_spec.context.test_output_json_filepath =
      got.run_spec.context.test_output_json_filepath
    want.run_spec.context.pos_id = got.run_spec.context.pos_id
    want.run_spec.context.process_test_results =
      got.run_spec.context.process_test_results
    want.strategy_result.output = got.strategy_result.output

    -- Copy output and short fields from got results to want results
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
  end)
end)
