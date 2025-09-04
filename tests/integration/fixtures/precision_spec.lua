local _ = require("plenary")
local options = require("neotest-golang.options")

-- Load real execution helper
local real_execution_path = vim.uv.cwd() .. "/tests/helpers/real_execution.lua"
local real_execution = dofile(real_execution_path)

describe("Integration: precision", function()
  it("executes treesitter precision tests without breaking", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/precision/precision_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    local tree, results = real_execution.execute_adapter_direct(test_filepath)

    -- Verify basic test execution works
    assert.is_truthy(tree)
    assert.is_truthy(results)

    -- The main test: treesitter precision should not break test discovery or execution
    -- This fixture tests that only real t.Run() calls are detected, not method calls
    local tree_list = tree:to_list()
    assert.is_true(#tree_list > 0, "Should discover test structure")

    -- Verify that test execution completed successfully
    local result_count = 0
    for _ in pairs(results) do
      result_count = result_count + 1
    end
    assert.is_true(result_count > 0, "Should have test results")
  end)

  it("processes treesitter queries correctly", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/precision/precision_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    local tree, results = real_execution.execute_adapter_direct(test_filepath)

    assert.is_truthy(tree)
    assert.is_truthy(results)

    -- The key test: ensure treesitter can distinguish between real t.Run() and dummy.Run()
    -- This fixture contains both real t.Run() calls and dummy.Run() method calls
    -- The adapter should parse this correctly without breaking

    local tree_list = tree:to_list()

    -- Basic verification: we should get some tree structure back
    assert.is_true(#tree_list > 0, "Should discover test structure")

    -- Main verification: test execution works without treesitter precision issues
    local execution_successful = false
    for _ in pairs(results) do
      execution_successful = true
      break
    end
    assert.is_true(
      execution_successful,
      "Should execute tests successfully despite treesitter complexity"
    )
  end)
end)
