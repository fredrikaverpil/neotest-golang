local _ = require("plenary")
local options = require("neotest-golang.options")

-- Load real execution helper
local integration_path = vim.uv.cwd() .. "/tests/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Integration: nested_packages", function()
  it("discovers tests in nested package directories", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    local subpackage2_test_path = vim.uv.cwd()
      .. "/tests/go/internal/nested/subpackage2/subpackage2_test.go"
    local subpackage3_test_path = vim.uv.cwd()
      .. "/tests/go/internal/nested/subpackage2/subpackage3/subpackage3_test.go"

    subpackage2_test_path = integration.normalize_path(subpackage2_test_path)
    subpackage3_test_path = integration.normalize_path(subpackage3_test_path)

    -- Test discovery and execution of subpackage2 tests
    local tree2, results2 =
      integration.execute_adapter_direct(subpackage2_test_path)
    assert.is_truthy(tree2, "Should discover tests in subpackage2")
    assert.is_truthy(results2, "Should have results for subpackage2")

    -- Test discovery and execution of subpackage3 tests
    local tree3, results3 =
      integration.execute_adapter_direct(subpackage3_test_path)
    assert.is_truthy(tree3, "Should discover tests in subpackage3")
    assert.is_truthy(results3, "Should have results for subpackage3")

    -- Verify both nested packages have tests discovered
    local tree2_list = tree2:to_list()
    local tree3_list = tree3:to_list()

    assert.is_true(
      #tree2_list > 0,
      "Should discover test structure in subpackage2"
    )
    assert.is_true(
      #tree3_list > 0,
      "Should discover test structure in subpackage3"
    )

    -- Verify we can get test results from both nested packages
    local results2_count = 0
    for _ in pairs(results2) do
      results2_count = results2_count + 1
    end

    local results3_count = 0
    for _ in pairs(results3) do
      results3_count = results3_count + 1
    end

    assert.is_true(
      results2_count > 0,
      "Should have test results from subpackage2"
    )
    assert.is_true(
      results3_count > 0,
      "Should have test results from subpackage3"
    )
  end)

  it("handles deep directory structures correctly", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    -- Test that the adapter correctly handles nested directory structures
    -- where tests are in different packages at different nesting levels
    local deepest_test_path = vim.uv.cwd()
      .. "/tests/go/internal/nested/subpackage2/subpackage3/subpackage3_test.go"
    deepest_test_path = integration.normalize_path(deepest_test_path)

    local tree, results = integration.execute_adapter_direct(deepest_test_path)

    assert.is_truthy(
      tree,
      "Should discover test structure in deeply nested package"
    )
    assert.is_truthy(
      results,
      "Should have test results from deeply nested package"
    )

    -- The key test: verify that the adapter correctly handles the deepest nested package
    local tree_list = tree:to_list()
    assert.is_true(
      #tree_list > 0,
      "Should discover tests correctly in deeply nested packages"
    )

    -- Verify results are properly structured for deeply nested packages
    local has_results = false
    for _ in pairs(results) do
      has_results = true
      break
    end
    assert.is_true(
      has_results,
      "Should execute tests correctly in deeply nested packages"
    )
  end)

  it("verifies go list works correctly for nested packages", function()
    -- Test that Go tooling correctly recognizes the nested package structure
    local subpackage2_cmd = string.format(
      "cd %s && go list -json %s",
      vim.uv.cwd() .. "/tests/go",
      "github.com/fredrikaverpil/neotest-golang/internal/nested/subpackage2"
    )

    local subpackage3_cmd = string.format(
      "cd %s && go list -json %s",
      vim.uv.cwd() .. "/tests/go",
      "github.com/fredrikaverpil/neotest-golang/internal/nested/subpackage2/subpackage3"
    )

    local result2 = vim.fn.system(subpackage2_cmd)
    local result3 = vim.fn.system(subpackage3_cmd)

    -- Parse the JSON results
    local ok2, json_result2 = pcall(vim.json.decode, result2)
    local ok3, json_result3 = pcall(vim.json.decode, result3)

    assert.is_truthy(ok2, "Should get valid JSON from go list for subpackage2")
    assert.is_truthy(ok3, "Should get valid JSON from go list for subpackage3")

    -- Verify both packages have test files
    assert.is_truthy(
      json_result2.TestGoFiles and #json_result2.TestGoFiles > 0,
      "subpackage2 should have test files"
    )
    assert.is_truthy(
      json_result3.TestGoFiles and #json_result3.TestGoFiles > 0,
      "subpackage3 should have test files"
    )

    -- Verify package names are correct
    assert.are.equal(
      "subpackage2",
      json_result2.Name,
      "subpackage2 should have correct package name"
    )
    assert.are.equal(
      "subpackage3",
      json_result3.Name,
      "subpackage3 should have correct package name"
    )
  end)
end)
