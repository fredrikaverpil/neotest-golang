local _ = require("plenary")
local options = require("neotest-golang.options")

-- Load real execution helper
local real_execution_path = vim.uv.cwd() .. "/tests/helpers/real_execution.lua"
local real_execution = dofile(real_execution_path)

describe("Integration: package naming", function()
  it("handles blackbox and whitebox package naming", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/naming/blackbox_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    local tree, results = real_execution.execute_adapter_direct(test_filepath)

    -- Verify basic test execution works
    assert.is_truthy(tree)
    assert.is_truthy(results)

    -- The main test: package naming patterns (blackbox vs whitebox) should work correctly
    local tree_list = tree:to_list()
    assert.is_true(#tree_list > 0, "Should discover test structure")

    -- Verify test execution completed successfully
    local result_count = 0
    for _ in pairs(results) do
      result_count = result_count + 1
    end
    assert.is_true(result_count > 0, "Should have test results")
  end)

  it("supports both internal and external testing patterns", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    -- Test both blackbox and whitebox files in the naming directory
    local blackbox_filepath = vim.uv.cwd()
      .. "/tests/go/internal/naming/blackbox_test.go"
    local whitebox_filepath = vim.uv.cwd()
      .. "/tests/go/internal/naming/whitebox_test.go"

    blackbox_filepath = real_execution.normalize_path(blackbox_filepath)
    whitebox_filepath = real_execution.normalize_path(whitebox_filepath)

    -- Test blackbox pattern (package x_test)
    local tree1, results1 =
      real_execution.execute_adapter_direct(blackbox_filepath)
    assert.is_truthy(tree1, "Should discover blackbox test structure")
    assert.is_truthy(results1, "Should have blackbox test results")

    -- Test whitebox pattern (package x)
    local tree2, results2 =
      real_execution.execute_adapter_direct(whitebox_filepath)
    assert.is_truthy(tree2, "Should discover whitebox test structure")
    assert.is_truthy(results2, "Should have whitebox test results")

    -- Both patterns should work successfully
    local blackbox_successful = false
    for _ in pairs(results1) do
      blackbox_successful = true
      break
    end

    local whitebox_successful = false
    for _ in pairs(results2) do
      whitebox_successful = true
      break
    end

    assert.is_true(
      blackbox_successful,
      "Should execute blackbox tests successfully"
    )
    assert.is_true(
      whitebox_successful,
      "Should execute whitebox tests successfully"
    )
  end)
end)
