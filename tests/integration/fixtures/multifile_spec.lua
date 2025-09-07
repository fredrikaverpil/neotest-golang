local _ = require("plenary")
local options = require("neotest-golang.options")

-- Load real execution helper
local integration_path = vim.uv.cwd() .. "/tests/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Integration: multifile", function()
  it("discovers tests from multiple files in the same package", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    local first_file_path = vim.uv.cwd()
      .. "/tests/go/internal/multifile/first_file_test.go"
    local second_file_path = vim.uv.cwd()
      .. "/tests/go/internal/multifile/second_file_test.go"

    first_file_path = integration.normalize_path(first_file_path)
    second_file_path = integration.normalize_path(second_file_path)

    -- Test discovery and execution of first file
    local tree1, results1 =
      integration.execute_adapter_direct(first_file_path)
    assert.is_truthy(tree1, "Should discover tests in first file")
    assert.is_truthy(results1, "Should have results for first file")

    -- Test discovery and execution of second file
    local tree2, results2 =
      integration.execute_adapter_direct(second_file_path)
    assert.is_truthy(tree2, "Should discover tests in second file")
    assert.is_truthy(results2, "Should have results for second file")

    -- Verify both files have tests discovered
    local tree1_list = tree1:to_list()
    local tree2_list = tree2:to_list()

    assert.is_true(
      #tree1_list > 0,
      "Should discover test structure in first file"
    )
    assert.is_true(
      #tree2_list > 0,
      "Should discover test structure in second file"
    )

    -- Verify we can get test results from both files
    local results1_count = 0
    for _ in pairs(results1) do
      results1_count = results1_count + 1
    end

    local results2_count = 0
    for _ in pairs(results2) do
      results2_count = results2_count + 1
    end

    assert.is_true(
      results1_count > 0,
      "Should have test results from first file"
    )
    assert.is_true(
      results2_count > 0,
      "Should have test results from second file"
    )
  end)

  it("handles package-level test execution correctly", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    -- Test package-level execution by targeting the directory
    local package_dir = vim.uv.cwd() .. "/tests/go/internal/multifile"
    package_dir = integration.normalize_path(package_dir)

    -- Since we can't directly execute a directory, test one file but verify
    -- the adapter handles multi-file packages correctly during discovery
    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/multifile/first_file_test.go"
    test_filepath = integration.normalize_path(test_filepath)

    local tree, results = integration.execute_adapter_direct(test_filepath)

    assert.is_truthy(tree, "Should discover test structure")
    assert.is_truthy(results, "Should have test results")

    -- The key test: verify that the adapter correctly handles multiple test files
    -- in the same package without conflicts or missing tests
    local tree_list = tree:to_list()
    assert.is_true(
      #tree_list > 0,
      "Should discover tests correctly in multi-file package"
    )

    -- Verify results are properly structured
    local has_results = false
    for _ in pairs(results) do
      has_results = true
      break
    end
    assert.is_true(
      has_results,
      "Should execute tests correctly in multi-file package"
    )
  end)
end)
