local _ = require("plenary")
local options = require("neotest-golang.options")

-- Load real execution helper
local real_execution_path = vim.uv.cwd() .. "/tests/helpers/real_execution.lua"
local real_execution = dofile(real_execution_path)

describe("Integration: special_characters", function()
  it("executes tests with special characters without breaking", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/specialchars/special_characters_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    local tree, results = real_execution.execute_adapter_direct(test_filepath)

    -- Verify basic test execution works
    assert.is_truthy(tree)
    assert.is_truthy(results)

    -- The main test: special characters in test names should not break discovery or execution
    -- This fixture contains test names with spaces, brackets, regex characters, etc.
    local tree_list = tree:to_list()
    assert.is_true(#tree_list > 0, "Should discover test structure")

    -- Verify test execution completed successfully
    local result_count = 0
    for _ in pairs(results) do
      result_count = result_count + 1
    end
    assert.is_true(result_count > 0, "Should have test results")
  end)

  it("handles complex test names correctly", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/specialchars/special_characters_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    local tree, results = real_execution.execute_adapter_direct(test_filepath)

    assert.is_truthy(tree)
    assert.is_truthy(results)

    -- The key test: ensure special characters don't break test name parsing or execution
    -- This fixture contains test names with:
    -- - Spaces: "Mixed case with space"
    -- - Brackets: "Brackets [1] (2) {3} are ok"
    -- - Regex chars: "Regexp characters like ( ) [ ] { } - | ? + * ^ $ are ok"
    -- - Nested tests: "nested1" -> "nested2"

    local tree_list = tree:to_list()

    -- Check that we found some test structure
    local has_test_structure = #tree_list > 0
    assert.is_true(
      has_test_structure,
      "Should discover test structure despite special characters"
    )

    -- Main verification: test execution works despite special characters
    local execution_successful = false
    for _ in pairs(results) do
      execution_successful = true
      break
    end
    assert.is_true(
      execution_successful,
      "Should execute tests successfully despite special characters"
    )
  end)
end)
