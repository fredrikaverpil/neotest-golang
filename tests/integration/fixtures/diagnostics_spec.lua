local _ = require("plenary")
local options = require("neotest-golang.options")

-- Load real execution helper
local real_execution_path = vim.uv.cwd() .. "/tests/helpers/real_execution.lua"
local real_execution = dofile(real_execution_path)

describe("Integration: diagnostics", function()
  it("executes tests with diagnostic messages without breaking", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/diagnostics/diagnostics_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    local tree, results = real_execution.execute_adapter_direct(test_filepath)

    -- Verify basic test execution works
    assert.is_truthy(tree)
    assert.is_truthy(results)

    -- The key test: diagnostic classification should not break test discovery or execution
    -- This fixture contains tests with t.Log() calls that generate diagnostic messages
    local tree_list = tree:to_list()
    assert.is_true(#tree_list > 0, "Should discover test structure")

    -- Verify that test execution completed successfully (we get results back)
    local result_count = 0
    for _ in pairs(results) do
      result_count = result_count + 1
    end
    assert.is_true(result_count > 0, "Should have test results")
  end)

  it("handles tests with hint-like log messages", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/diagnostics/diagnostics_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    -- Execute just the tests that should pass (contain t.Log calls)
    local tree, results = real_execution.execute_adapter_direct(
      test_filepath,
      "TestDiagnostics|TestDiagnosticsTopLevelLog"
    )

    assert.is_truthy(tree)
    assert.is_truthy(results)

    -- Verify that tests with t.Log() calls execute successfully
    -- The diagnostic classification should handle hint messages without breaking execution
    local passing_tests = 0
    for _, result in pairs(results) do
      if result.status == "passed" then
        passing_tests = passing_tests + 1
      end
    end

    -- Should have some passing tests (exact count may vary based on subtests)
    assert.is_true(
      passing_tests > 0,
      "Should have passing tests with t.Log() calls"
    )
  end)
end)
