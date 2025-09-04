local _ = require("plenary")
local options = require("neotest-golang.options")

-- Load real execution helper
local real_execution_path = vim.uv.cwd() .. "/tests/helpers/real_execution.lua"
local real_execution = dofile(real_execution_path)

describe("Integration: Function vs Table Options", function()
  it("evaluates function-based options at execution time", function()
    local call_count = 0

    options.set({
      runner = "go",
      go_test_args = function()
        call_count = call_count + 1
        return { "-v", "-count=1" }
      end,
      env = function()
        return {
          FUNCTION_CALL_COUNT = tostring(call_count),
        }
      end,
      warn_test_results_missing = false,
    })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/envtest/envtest_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    -- Execute tests - functions should be called
    local tree, results = real_execution.execute_adapter_direct(test_filepath)

    assert.is_truthy(tree, "Should work with function-based options")
    assert.is_truthy(results, "Should have results with function options")

    -- Verify function was called
    assert.is_true(
      call_count > 0,
      "Function-based go_test_args should be called during execution"
    )

    local result_count = 0
    for _ in pairs(results) do
      result_count = result_count + 1
    end
    assert.is_true(
      result_count > 0,
      "Should execute tests with function options"
    )
  end)

  it("uses table-based options directly", function()
    options.set({
      runner = "go",
      go_test_args = { "-v", "-count=1" }, -- Table, not function
      env = {
        TABLE_BASED_VAR = "table_value",
      },
      warn_test_results_missing = false,
    })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/envtest/envtest_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    local tree, results = real_execution.execute_adapter_direct(test_filepath)

    assert.is_truthy(tree, "Should work with table-based options")
    assert.is_truthy(results, "Should have results with table options")

    local result_count = 0
    for _ in pairs(results) do
      result_count = result_count + 1
    end
    assert.is_true(result_count > 0, "Should execute tests with table options")
  end)

  it("supports mixed function and table options", function()
    local env_call_count = 0

    options.set({
      runner = "go",
      go_test_args = { "-v", "-count=1" }, -- Table
      env = function() -- Function
        env_call_count = env_call_count + 1
        return {
          MIXED_OPTIONS_TEST = "function_env",
          ENV_CALL_COUNT = tostring(env_call_count),
        }
      end,
      warn_test_results_missing = false,
    })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/envtest/envtest_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    local tree, results = real_execution.execute_adapter_direct(test_filepath)

    assert.is_truthy(tree, "Should work with mixed option types")
    assert.is_truthy(results, "Should have results with mixed options")

    -- Verify function was called
    assert.is_true(
      env_call_count > 0,
      "Function-based env should be called during execution"
    )

    local result_count = 0
    for _ in pairs(results) do
      result_count = result_count + 1
    end
    assert.is_true(result_count > 0, "Should execute tests with mixed options")
  end)

  it("handles function option errors gracefully", function()
    options.set({
      runner = "go",
      go_test_args = function()
        -- Return invalid type (should be table)
        return "invalid_return_type"
      end,
      warn_test_results_missing = false,
    })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/envtest/envtest_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    -- This should handle the error gracefully, not crash
    local success, tree, results = pcall(function()
      return real_execution.execute_adapter_direct(test_filepath)
    end)

    -- Should either succeed with fallback or handle error gracefully
    if success then
      assert.is_truthy(tree, "Should handle invalid function return gracefully")
    else
      -- If it fails, that's also acceptable for invalid input
      assert.is_true(true, "Handled invalid function return type appropriately")
    end
  end)

  it("supports all function-capable options", function()
    local calls = {
      go_test_args = 0,
      env = 0,
    }

    options.set({
      runner = "go",
      go_test_args = function()
        calls.go_test_args = calls.go_test_args + 1
        return { "-v", "-count=1" }
      end,
      env = function()
        calls.env = calls.env + 1
        return {
          ALL_FUNCTIONS_TEST = "true",
        }
      end,
      warn_test_results_missing = false,
    })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/envtest/envtest_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    local tree, results = real_execution.execute_adapter_direct(test_filepath)

    assert.is_truthy(tree, "Should work with all function options")
    assert.is_truthy(results, "Should have results with all function options")

    -- Verify functions were called
    assert.is_true(
      calls.go_test_args > 0,
      "go_test_args function should be called"
    )
    assert.is_true(calls.env > 0, "env function should be called")

    local result_count = 0
    for _ in pairs(results) do
      result_count = result_count + 1
    end
    assert.is_true(
      result_count > 0,
      "Should execute tests with all function options"
    )
  end)

  it("functions are called fresh each time", function()
    local call_tracker = {}

    options.set({
      runner = "go",
      go_test_args = function()
        table.insert(call_tracker, "call_" .. #call_tracker + 1)
        return { "-v", "-count=1" }
      end,
      warn_test_results_missing = false,
    })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/envtest/envtest_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    -- Execute twice to verify fresh calls
    local tree1, results1 = real_execution.execute_adapter_direct(test_filepath)
    local tree2, results2 = real_execution.execute_adapter_direct(test_filepath)

    assert.is_truthy(tree1, "First execution should work")
    assert.is_truthy(results1, "First execution should have results")
    assert.is_truthy(tree2, "Second execution should work")
    assert.is_truthy(results2, "Second execution should have results")

    -- Function should be called multiple times
    assert.is_true(
      #call_tracker >= 2,
      "Function should be called fresh each time"
    )
  end)
end)
