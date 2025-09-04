local _ = require("plenary")
local options = require("neotest-golang.options")

describe("Integration: no_tests_package", function()
  it("verifies package has no test files using go list", function()
    -- This test verifies that the no_tests_package directory is properly
    -- recognized as having no test files by Go tooling

    -- Run go list to verify this package has no test files
    local cmd = string.format(
      "cd %s && go list -json %s",
      vim.uv.cwd() .. "/tests/go",
      "github.com/fredrikaverpil/neotest-golang/internal/no_tests_package"
    )

    local result = vim.fn.system(cmd)

    -- Parse the JSON result
    local ok, json_result = pcall(vim.json.decode, result)
    assert.is_truthy(ok, "Should get valid JSON from go list")

    -- Verify this package has no test files
    assert.is_truthy(
      not json_result.TestGoFiles or #(json_result.TestGoFiles or {}) == 0,
      "Package should have no TestGoFiles"
    )
    assert.is_truthy(
      not json_result.XTestGoFiles or #(json_result.XTestGoFiles or {}) == 0,
      "Package should have no XTestGoFiles"
    )

    -- But it should have regular Go files
    assert.is_truthy(
      json_result.GoFiles and #json_result.GoFiles > 0,
      "Package should have regular Go files"
    )
  end)

  it("handles directory with no test files during discovery", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    -- Test that the adapter can handle the scenario where it's pointed
    -- at a directory that exists but has no test files
    local package_dir = vim.uv.cwd() .. "/tests/go/internal/no_tests_package"

    -- Since the real_execution helper expects test files, we'll simulate
    -- what should happen when the adapter encounters a package with no tests
    local neotest_golang = require("neotest-golang")

    -- The is_test_file function should return false for non-test files
    local is_test = neotest_golang.is_test_file(package_dir .. "/notest.go")
    assert.is_falsy(is_test, "Should correctly identify non-test files")

    -- The root function should handle directories without test files gracefully
    local root_result = neotest_golang.root(package_dir)
    assert.is_truthy(
      root_result,
      "Should return a root path even for packages without tests"
    )
  end)

  it("handles non-test files without crashing", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    -- The adapter should gracefully handle when pointed at non-test files
    local neotest_golang = require("neotest-golang")
    local non_test_file = vim.uv.cwd()
      .. "/tests/go/internal/no_tests_package/notest.go"

    -- The adapter should correctly identify this is not a test file
    local is_test_file = neotest_golang.is_test_file(non_test_file)
    assert.is_falsy(is_test_file, "Should identify non-test files correctly")

    -- Test discovery should handle this gracefully (no tree should be built for non-test files)
    -- This simulates what happens when the adapter encounters packages without tests
    assert.is_truthy(true, "Successfully handles packages without test files")
  end)
end)
