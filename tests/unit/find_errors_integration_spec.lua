describe("find_errors integration", function()
  local process = require("neotest-golang.process")

  it(
    "should correctly differentiate hints from errors in find_errors",
    function()
      -- Mock accumulated test data with sample output
      local accum = {
        ["test_package::TestExample"] = {
          status = "running",
          output = table.concat({
            "=== RUN   TestExample",
            "go:8: This is a test log message",
            "go:12: Starting computation",
            "go:15: panic: something went wrong",
            "go:20: Debug info about test state",
            "go:25: Expected value 42, but got 24",
            "go:30: Cleanup complete",
            "--- FAIL: TestExample (0.01s)",
          }, "\n"),
          errors = {},
        },
      }

      -- Run find_errors
      local result = process.find_errors(accum, "test_package::TestExample")
      local errors = result["test_package::TestExample"].errors

      -- Should have 6 diagnostic entries total
      assert.equals(6, #errors)

      -- Check that hints are properly identified (lines 8, 12, 20, 30)
      local hint_lines = {}
      local error_lines = {}

      for _, err in ipairs(errors) do
        if err.severity == vim.diagnostic.severity.HINT then
          table.insert(hint_lines, err.line + 1) -- Convert back to 1-indexed for checking
        else
          table.insert(error_lines, err.line + 1)
        end
      end

      -- Should have 4 hints and 2 errors
      assert.equals(4, #hint_lines)
      assert.equals(2, #error_lines)

      -- Check specific lines are categorized correctly
      assert.is_true(vim.tbl_contains(hint_lines, 8)) -- "This is a test log message"
      assert.is_true(vim.tbl_contains(hint_lines, 12)) -- "Starting computation"
      assert.is_true(vim.tbl_contains(hint_lines, 20)) -- "Debug info about test state"
      assert.is_true(vim.tbl_contains(hint_lines, 30)) -- "Cleanup complete"

      assert.is_true(vim.tbl_contains(error_lines, 15)) -- "panic: something went wrong"
      assert.is_true(vim.tbl_contains(error_lines, 25)) -- "Expected value 42, but got 24"
    end
  )

  it("should handle output with no go: patterns", function()
    local accum = {
      ["test_package::TestSimple"] = {
        status = "running",
        output = table.concat({
          "=== RUN   TestSimple",
          "Running test...",
          "Test completed successfully",
          "--- PASS: TestSimple (0.00s)",
        }, "\n"),
        errors = {},
      },
    }

    local result = process.find_errors(accum, "test_package::TestSimple")
    local errors = result["test_package::TestSimple"].errors

    -- Should have no diagnostic entries
    assert.equals(0, #errors)
  end)
end)
