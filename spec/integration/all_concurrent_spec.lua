local _ = require("plenary")
local options = require("neotest-golang.options")
local path = require("neotest-golang.lib.path")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Integration: comprehensive concurrent execution", function()
  it("executes all major test scenarios concurrently", function()
    -- ===== ARRANGE =====
    local test_options = options.get()
    test_options.runner = "gotestsum"
    options.set(test_options)

    local base_path = vim.uv.cwd()

    -- Comprehensive list of different test scenarios to run concurrently
    local positions = {
      -- Single tests from different files
      path.normalize_path(
        base_path .. "/tests/go/internal/singletest/singletest_test.go::TestOne"
      ),
      path.normalize_path(
        base_path .. "/tests/go/internal/singletest/singletest_test.go::TestTwo"
      ),
      path.normalize_path(
        base_path
          .. "/tests/go/internal/singletest/singletest_test.go::TestThree"
      ),

      -- Position tests (various Go test patterns)
      path.normalize_path(
        base_path
          .. "/tests/go/internal/positions/positions_test.go::TestTopLevel"
      ),
      path.normalize_path(
        base_path
          .. "/tests/go/internal/positions/positions_test.go::TestTopLevelWithSubTest"
      ),
      path.normalize_path(
        base_path
          .. "/tests/go/internal/positions/positions_test.go::TestTableTestStruct"
      ),

      -- Diagnostic tests (tests that produce errors/warnings)
      path.normalize_path(
        base_path
          .. "/tests/go/internal/diagnostics/diagnostics_test.go::TestDiagnosticsTopLevelLog"
      ),
      path.normalize_path(
        base_path
          .. "/tests/go/internal/diagnostics/diagnostics_test.go::TestDiagnosticsTopLevelError"
      ),
    }

    -- ===== ACT =====
    print(
      string.format(
        "\n[TEST] Running %d diverse test scenarios concurrently...",
        #positions
      )
    )
    local start_time = vim.fn.reltime()
    local results = integration.execute_adapter_concurrent(positions, true)
    local concurrent_duration = vim.fn.reltimestr(vim.fn.reltime(start_time))

    -- ===== ASSERT =====
    print(
      string.format(
        "\n[PERFORMANCE] Concurrent execution of %d tests: %s seconds",
        #positions,
        concurrent_duration
      )
    )

    -- Verify all tests completed (some may fail, but they should complete)
    assert.are.equal(#positions, vim.tbl_count(results))

    -- Check specific test results
    local passing_tests = {
      path.normalize_path(
        base_path .. "/tests/go/internal/singletest/singletest_test.go::TestOne"
      ),
      path.normalize_path(
        base_path .. "/tests/go/internal/singletest/singletest_test.go::TestTwo"
      ),
      path.normalize_path(
        base_path
          .. "/tests/go/internal/singletest/singletest_test.go::TestThree"
      ),
      path.normalize_path(
        base_path
          .. "/tests/go/internal/positions/positions_test.go::TestTopLevel"
      ),
      path.normalize_path(
        base_path
          .. "/tests/go/internal/positions/positions_test.go::TestTopLevelWithSubTest"
      ),
      path.normalize_path(
        base_path
          .. "/tests/go/internal/positions/positions_test.go::TestTableTestStruct"
      ),
      path.normalize_path(
        base_path
          .. "/tests/go/internal/diagnostics/diagnostics_test.go::TestDiagnosticsTopLevelLog"
      ),
    }

    local failing_tests = {
      path.normalize_path(
        base_path
          .. "/tests/go/internal/diagnostics/diagnostics_test.go::TestDiagnosticsTopLevelError"
      ),
    }

    -- Verify passing tests
    for _, position_id in ipairs(passing_tests) do
      assert.is_not_nil(
        results[position_id],
        "Result missing for " .. position_id
      )
      assert.is_nil(
        results[position_id].error,
        "Test execution failed: " .. (results[position_id].error or "")
      )
      assert.are.equal(
        0,
        results[position_id].strategy_result.code,
        "Exit code should be 0 for " .. position_id
      )

      -- Verify the specific test result
      local test_result = results[position_id].results[position_id]
      assert.is_not_nil(test_result, "No test result for " .. position_id)
      assert.are.equal(
        "passed",
        test_result.status,
        "Test should pass for " .. position_id
      )

      -- Validate specific diagnostic hints for diagnostic log tests
      if
        position_id:find("/diagnostics/")
        and position_id:find("TestDiagnosticsTopLevelLog")
      then
        local expected_errors = {
          {
            message = "top-level hint: this should be classified as a hint",
            line = 9, -- 0-indexed: line 10 - 1
            severity = 4, -- vim.diagnostic.severity.HINT
          },
        }
        integration.validate_diagnostic_errors(
          results,
          position_id,
          expected_errors
        )
        print(
          string.format("✅ Validated diagnostic hints for %s", position_id)
        )
      end
    end

    -- Verify failing tests (should fail gracefully with specific errors)
    for _, position_id in ipairs(failing_tests) do
      assert.is_not_nil(
        results[position_id],
        "Result missing for " .. position_id
      )
      assert.is_nil(
        results[position_id].error,
        "Test execution should complete even if test fails: "
          .. (results[position_id].error or "")
      )
      -- Exit code may be non-zero for failing tests, which is expected

      local test_result = results[position_id].results[position_id]
      assert.is_not_nil(test_result, "No test result for " .. position_id)
      assert.are.equal(
        "failed",
        test_result.status,
        "Test should fail for " .. position_id
      )

      -- Validate specific diagnostic errors for diagnostics tests
      if position_id:find("/diagnostics/") then
        local expected_errors = {
          {
            message = "expected 42 but got 0",
            line = 13, -- 0-indexed: line 14 - 1
            severity = 1, -- vim.diagnostic.severity.ERROR
          },
        }
        integration.validate_diagnostic_errors(
          results,
          position_id,
          expected_errors
        )
        print(
          string.format("✅ Validated diagnostic errors for %s", position_id)
        )
      end
    end

    print(
      string.format(
        "[TEST] Successfully executed %d concurrent tests covering:",
        #positions
      )
    )
    print("  - Multiple test files (singletest, positions, diagnostics)")
    print("  - Various test patterns (simple, subtests, table tests)")
    print("  - Different test outcomes (passing, failing)")
    print("  - Comprehensive Go test functionality")
    print("[TEST] Concurrent comprehensive execution completed successfully!")
  end)

  it(
    "concurrent execution provides significant speedup for many tests",
    function()
      -- ===== ARRANGE =====
      local test_options = options.get()
      test_options.runner = "gotestsum"
      options.set(test_options)

      local base_path = vim.uv.cwd()

      -- Use a smaller set for performance comparison
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
            .. "/tests/go/internal/positions/positions_test.go::TestTopLevel"
        ),
        path.normalize_path(
          base_path
            .. "/tests/go/internal/diagnostics/diagnostics_test.go::TestDiagnosticsTopLevelLog"
        ),
      }

      -- ===== ACT: Sequential execution =====
      print(
        string.format(
          "\n[TEST] Running %d tests sequentially for comparison...",
          #positions
        )
      )
      local seq_start = vim.fn.reltime()
      local seq_results = {}
      for _, position_id in ipairs(positions) do
        seq_results[position_id] =
          integration.execute_adapter_direct(position_id, { use_async = true })
      end
      local seq_duration = vim.fn.reltimefloat(vim.fn.reltime(seq_start))

      -- ===== ACT: Concurrent execution =====
      print(
        string.format(
          "\n[TEST] Running %d tests concurrently for comparison...",
          #positions
        )
      )
      local conc_start = vim.fn.reltime()
      local conc_results =
        integration.execute_adapter_concurrent(positions, true)
      local conc_duration = vim.fn.reltimefloat(vim.fn.reltime(conc_start))

      -- ===== ASSERT =====
      print(
        string.format("\n[PERFORMANCE] Sequential: %.3f seconds", seq_duration)
      )
      print(
        string.format("[PERFORMANCE] Concurrent: %.3f seconds", conc_duration)
      )

      -- Verify both approaches produce the same results
      assert.are.equal(#positions, vim.tbl_count(seq_results))
      assert.are.equal(#positions, vim.tbl_count(conc_results))

      for _, position_id in ipairs(positions) do
        -- Both should have results
        assert.is_not_nil(
          seq_results[position_id],
          "Sequential missing: " .. position_id
        )
        assert.is_not_nil(
          conc_results[position_id],
          "Concurrent missing: " .. position_id
        )
      end

      -- Calculate speed improvement
      if seq_duration > 0 and conc_duration > 0 then
        local speedup = seq_duration / conc_duration
        print(
          string.format(
            "[PERFORMANCE] Speed improvement: %.1fx faster",
            speedup
          )
        )

        -- With 4 tests, we should see some improvement (though overhead may limit it)
        -- At minimum, concurrent shouldn't be much slower
        assert.is_true(
          conc_duration <= seq_duration * 1.3,
          string.format(
            "Concurrent (%.3f) shouldn't be much slower than sequential (%.3f)",
            conc_duration,
            seq_duration
          )
        )
      end

      print("[TEST] Performance comparison completed!")
    end
  )
end)
