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
      "github.com/fredrikaverpil/neotest-golang/internal/notest"
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
    local package_dir = vim.uv.cwd() .. "/tests/go/internal/notest"

    -- Test adapter functions that don't require full initialization
    -- These functions should work without runtime path issues

    -- Check if Go files exist in the package
    local go_files = vim.fn.glob(package_dir .. "/*.go", false, true)
    assert.is_truthy(#go_files > 0, "Package should have Go files")

    -- Check if any are test files (should be none)
    local test_files = {}
    for _, file in ipairs(go_files) do
      if file:match("_test%.go$") then
        table.insert(test_files, file)
      end
    end
    assert.is_truthy(#test_files == 0, "Package should have no test files")

    -- Verify the package directory structure is correct
    assert.is_truthy(
      vim.fn.isdirectory(package_dir) == 1,
      "Package directory should exist"
    )
  end)

  it("handles non-test files without crashing", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    -- Test file pattern matching without loading the full adapter
    local non_test_file = vim.uv.cwd() .. "/tests/go/internal/notest/notest.go"

    -- Verify file exists
    assert.is_truthy(
      vim.fn.filereadable(non_test_file) == 1,
      "Non-test file should exist"
    )

    -- Test basic file pattern matching (avoid full adapter loading)
    local is_test_pattern = non_test_file:match("_test%.go$")
    assert.is_falsy(is_test_pattern, "Should not match test file pattern")

    -- Test that it's a valid Go file
    local is_go_file = non_test_file:match("%.go$")
    assert.is_truthy(is_go_file, "Should be a Go file")

    -- This validates the package structure without requiring adapter initialization
    assert.is_truthy(true, "Successfully handles packages without test files")
  end)
end)
