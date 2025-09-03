describe("pattern matching performance", function()
  local diagnostics = require("neotest-golang.lib.diagnostics")

  it("should correctly parse various Go output formats", function()
    local test_cases = {
      {
        line = "go:123: This is a debug message",
        expected = { line_number = 123, message = "This is a debug message" },
      },
      {
        line = "database_test.go:456: using emulator",
        expected = { line_number = 456, message = "using emulator" },
      },
      {
        line = "  file_test.go:789: indented message",
        expected = { line_number = 789, message = "indented message" },
      },
      {
        line = "go:42: panic: something went wrong",
        expected = { line_number = 42, message = "panic: something went wrong" },
      },
      { line = "invalid line format", expected = nil },
    }

    for _, case in ipairs(test_cases) do
      local result = diagnostics.parse_diagnostic_line(case.line)

      if case.expected then
        assert.is_not_nil(result, "Should parse: " .. case.line)
        assert.equals(case.expected.line_number, result.line_number)
        assert.equals(case.expected.message, result.message)
      else
        assert.is_nil(result, "Should not parse: " .. case.line)
      end
    end
  end)

  it("should correctly classify messages as hints vs errors", function()
    local test_cases = {
      { message = "Debug information logged", expected_hint = true },
      { message = "Test completed successfully", expected_hint = true },
      { message = "panic: nil pointer dereference", expected_hint = false },
      {
        message = "assertion failed: values don't match",
        expected_hint = false,
      },
      { message = "expected 42 but got 24", expected_hint = false },
      { message = "error: connection failed", expected_hint = false },
      { message = "FAIL: test assertion failed", expected_hint = false },
      { message = "runtime error: index out of range", expected_hint = false },
    }

    for _, case in ipairs(test_cases) do
      local is_hint = diagnostics.is_hint_message(case.message)
      assert.equals(case.expected_hint, is_hint, "Message: " .. case.message)
    end
  end)

  it("should handle single-pass pattern matching correctly", function()
    -- Test that our new single-pass approach produces correct results
    local test_lines = {
      "go:8: This is a test log message",
      "go:15: panic: something went wrong",
      "database_test.go:25: using emulator from environment",
      "go:30: Debug info about test state",
    }

    local results = {}
    for _, line in ipairs(test_lines) do
      local diagnostic = diagnostics.parse_diagnostic_line(line)
      if diagnostic then
        table.insert(results, {
          line = diagnostic.line_number - 1, -- 0-indexed for neovim
          message = diagnostic.message,
          severity = diagnostic.severity,
        })
      end
    end

    -- Should have 4 diagnostics
    assert.equals(4, #results)

    -- Check that hints and errors are classified correctly
    local hints = {}
    local errors = {}
    for _, result in ipairs(results) do
      if result.severity == vim.diagnostic.severity.HINT then
        table.insert(hints, result.line + 1) -- convert back to 1-indexed for checking
      else
        table.insert(errors, result.line + 1)
      end
    end

    assert.equals(3, #hints) -- lines 8, 25, 30
    assert.equals(1, #errors) -- line 15 (panic)

    assert.is_true(vim.tbl_contains(hints, 8))
    assert.is_true(vim.tbl_contains(hints, 25))
    assert.is_true(vim.tbl_contains(hints, 30))
    assert.is_true(vim.tbl_contains(errors, 15))
  end)
end)
