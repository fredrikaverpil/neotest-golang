local _ = require("plenary")
local options = require("neotest-golang.options")
local path = require("neotest-golang.lib.path")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Integration: individual test example", function()
  it(
    "only runs the specified individual test (TestOne) in singletest_test.go",
    function()
      -- ===== ARRANGE =====
      local test_options = options.get()
      test_options.runner = "gotestsum"
      options.set(test_options)

      local position_id_file = vim.uv.cwd()
        .. path.os_path_sep
        .. "tests"
        .. path.os_path_sep
        .. "go"
        .. path.os_path_sep
        .. "internal"
        .. path.os_path_sep
        .. "singletest"
        .. path.os_path_sep
        .. "singletest_test.go"
      local position_id_test = position_id_file .. "::TestOne"

      -- Expected complete adapter execution result - only TestOne should run
      ---@type AdapterExecutionResult
      local want = {
        results = {
          -- Parent directory result
          [path.get_directory(path.get_directory(position_id_file))] = {
            status = "passed",
            errors = {},
          },
          -- Directory-level result (created by file aggregation)
          [path.get_directory(position_id_file)] = {
            status = "passed",
            errors = {},
          },
          -- File-level result
          [path.normalize_path(position_id_file)] = {
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

  it("tests sync execution timing", function()
    -- ===== ARRANGE =====
    local test_options = options.get()
    test_options.runner = "gotestsum"
    options.set(test_options)

    local position_id_file = vim.uv.cwd()
      .. path.os_path_sep
      .. "tests"
      .. path.os_path_sep
      .. "go"
      .. path.os_path_sep
      .. "internal"
      .. path.os_path_sep
      .. "singletest"
      .. path.os_path_sep
      .. "singletest_test.go"
    local position_id_test = position_id_file .. "::TestOne"

    -- ===== ACT =====
    print("\n[TEST] Starting SYNC execution for timing...")
    local start_time = vim.fn.reltime()
    local got_sync =
      integration.execute_adapter_direct(position_id_test, { use_async = true })
    local sync_duration = vim.fn.reltimestr(vim.fn.reltime(start_time))

    -- ===== ASSERT =====
    print(string.format("\n[PERFORMANCE] Sync: %s seconds", sync_duration))
    assert.are.equal(0, got_sync.strategy_result.code)
    assert.is_not_nil(got_sync.results[position_id_test])
    assert.are.equal("passed", got_sync.results[position_id_test].status)

    print("[TEST] Sync execution completed successfully!")
  end)

  it("tests async execution timing with streaming", function()
    -- ===== ARRANGE =====
    local test_options = options.get()
    test_options.runner = "gotestsum"
    options.set(test_options)

    local position_id_file = vim.uv.cwd()
      .. path.os_path_sep
      .. "tests"
      .. path.os_path_sep
      .. "go"
      .. path.os_path_sep
      .. "internal"
      .. path.os_path_sep
      .. "singletest"
      .. path.os_path_sep
      .. "singletest_test.go"
    local position_id_test = position_id_file .. "::TestOne"

    -- ===== ACT =====
    print("\n[TEST] Starting ASYNC execution with streaming...")
    local start_time = vim.fn.reltime()
    local got_async =
      integration.execute_adapter_direct(position_id_test, { use_async = true })
    local async_duration = vim.fn.reltimestr(vim.fn.reltime(start_time))

    -- ===== ASSERT =====
    print(string.format("\n[PERFORMANCE] Async: %s seconds", async_duration))
    assert.are.equal(0, got_async.strategy_result.code)
    assert.is_not_nil(got_async.results[position_id_test])
    assert.are.equal("passed", got_async.results[position_id_test].status)

    print("[TEST] Async execution completed successfully!")
  end)

  it(
    "tests concurrent execution of multiple tests in singletest file",
    function()
      -- ===== ARRANGE =====
      local test_options = options.get()
      test_options.runner = "gotestsum"
      options.set(test_options)

      local base_path = vim.uv.cwd()
      local positions = {
        path.normalize_path(
          base_path
            .. "/tests/go/internal/singletest/singletest_test.go::TestOne"
        ),
        path.normalize_path(
          base_path
            .. "/tests/go/internal/singletest/singletest_test.go::TestTwo"
        ),
        path.normalize_path(
          base_path
            .. "/tests/go/internal/singletest/singletest_test.go::TestThree"
        ),
      }

      -- ===== ACT =====
      print("\n[TEST] Running all singletest tests concurrently...")
      local start_time = vim.fn.reltime()
      local results = integration.execute_adapter_concurrent(positions, true)
      local concurrent_duration = vim.fn.reltimestr(vim.fn.reltime(start_time))

      -- ===== ASSERT =====
      print(
        string.format(
          "\n[PERFORMANCE] Concurrent singletest execution: %s seconds",
          concurrent_duration
        )
      )

      -- Verify all 3 tests completed successfully
      assert.are.equal(3, vim.tbl_count(results))

      for _, position_id in ipairs(positions) do
        assert.is_not_nil(
          results[position_id],
          "Result missing for " .. position_id
        )
        assert.is_nil(
          results[position_id].error,
          "Test failed: " .. (results[position_id].error or "")
        )
        assert.are.equal(
          0,
          results[position_id].strategy_result.code,
          "Exit code should be 0 for " .. position_id
        )

        -- Verify specific position results exist
        local test_result = results[position_id].results[position_id]
        assert.is_not_nil(test_result, "No test result for " .. position_id)
        assert.are.equal(
          "passed",
          test_result.status,
          "Test should pass for " .. position_id
        )
      end

      print("[TEST] Concurrent singletest execution completed successfully!")
    end
  )
end)
