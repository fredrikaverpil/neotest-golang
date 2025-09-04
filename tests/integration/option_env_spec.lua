local _ = require("plenary")
local options = require("neotest-golang.options")

-- Load real execution helper
local real_execution_path = vim.uv.cwd() .. "/tests/helpers/real_execution.lua"
local real_execution = dofile(real_execution_path)

describe("Integration: Environment Variables", function()
  it("injects environment variables as table", function()
    options.set({
      runner = "go",
      env = {
        NEOTEST_GO_VAR1 = "value1",
        NEOTEST_GO_VAR2 = "value2",
      },
      warn_test_results_missing = false,
    })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/envtest/envtest_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    local tree, results = real_execution.execute_adapter_direct(test_filepath)

    -- Verify basic execution works
    assert.is_truthy(tree, "Should discover test positions with env vars")
    assert.is_truthy(results, "Should have test results with env vars")

    -- Verify that tests ran (environment variables are logged, but we can't easily check logs)
    local result_count = 0
    for _ in pairs(results) do
      result_count = result_count + 1
    end
    assert.is_true(
      result_count > 0,
      "Should have test results with environment variables"
    )

    -- Verify tests pass (environment variables don't affect test outcome)
    local has_passed_test = false
    for _, result in pairs(results) do
      if result.status == "passed" then
        has_passed_test = true
        break
      end
    end
    assert.is_true(
      has_passed_test,
      "Should have at least one passed test with env vars"
    )
  end)

  it("supports environment variables as function", function()
    options.set({
      runner = "go",
      env = function()
        return {
          CUSTOM_ENV_VAR = "function_value",
          NEOTEST_GO_VAR1 = "from_function",
        }
      end,
      warn_test_results_missing = false,
    })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/envtest/envtest_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    local tree, results = real_execution.execute_adapter_direct(test_filepath)

    assert.is_truthy(tree, "Should discover test positions with function env")
    assert.is_truthy(results, "Should have test results with function env")

    -- Function-based env should work
    local result_count = 0
    for _ in pairs(results) do
      result_count = result_count + 1
    end
    assert.is_true(
      result_count > 0,
      "Should work with function-based environment variables"
    )
  end)

  it("handles empty environment variables gracefully", function()
    options.set({
      runner = "go",
      env = {}, -- Empty env vars
      warn_test_results_missing = false,
    })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/envtest/envtest_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    local tree, results = real_execution.execute_adapter_direct(test_filepath)

    assert.is_truthy(tree, "Should work with empty env vars")
    assert.is_truthy(results, "Should have results with empty env vars")

    -- Should still work with no environment variables
    local result_count = 0
    for _ in pairs(results) do
      result_count = result_count + 1
    end
    assert.is_true(
      result_count > 0,
      "Should work with empty environment variables"
    )
  end)

  it("allows mixing with existing environment", function()
    -- Test that our env vars don't break existing environment
    options.set({
      runner = "go",
      env = {
        PATH = vim.env.PATH, -- Explicitly pass through PATH
        HOME = vim.env.HOME, -- Explicitly pass through HOME
        NEOTEST_GO_VAR1 = "mixed_test",
      },
      warn_test_results_missing = false,
    })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/envtest/envtest_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    local tree, results = real_execution.execute_adapter_direct(test_filepath)

    assert.is_truthy(tree, "Should work with mixed environment")
    assert.is_truthy(results, "Should have results with mixed environment")

    -- Should work with mixed environment variables
    local result_count = 0
    for _ in pairs(results) do
      result_count = result_count + 1
    end
    assert.is_true(
      result_count > 0,
      "Should work with mixed environment variables"
    )
  end)
end)
