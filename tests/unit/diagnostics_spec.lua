describe("hint detection functionality", function()
  local lib = require("neotest-golang.lib")

  --- Checks if the given line contains t.Log or t.Logf output (should be treated as hint)
  --- Now uses optimized pattern parsing
  ---@param line string
  ---@return boolean
  local function is_test_log_hint(line)
    local diagnostic = lib.diagnostics.parse_diagnostic_line(line)
    if not diagnostic then
      return false
    end

    return diagnostic.severity == vim.diagnostic.severity.HINT
  end

  it("should identify t.Log messages as hints", function()
    local test_lines = {
      "go:8: This is a t.Log message - should be treated as hint, not error",
      "go:12: Math works correctly",
      "go:17: Starting test with some logging",
    }

    for _, line in ipairs(test_lines) do
      local is_hint = is_test_log_hint(line)
      assert.is_true(
        is_hint,
        "Expected line to be identified as hint: " .. line
      )
    end
  end)

  it("should identify error messages as errors", function()
    local test_lines = {
      "go:24: Expected 1+1 to equal 3, but it equals 2",
      "go:15: panic: something went wrong",
      "go:20: assertion failed: values don't match",
      "go:25: error: connection failed",
      "go:30: runtime error: index out of range",
    }

    for _, line in ipairs(test_lines) do
      local is_hint = is_test_log_hint(line)
      assert.is_false(
        is_hint,
        "Expected line to be identified as error: " .. line
      )
    end
  end)

  it("should extract hints from test output", function()
    local test_output = {
      "go:8: This is a t.Log message - should be treated as hint, not error",
      "go:12: Math works correctly",
      "go:24: Expected 1+1 to equal 3, but it equals 2",
    }

    local hints = lib.diagnostics.extract_hints_from_output(test_output)

    -- Should extract 2 hints (first two lines) and ignore the error (third line)
    assert.equals(2, #hints)

    assert.equals(7, hints[1].line) -- line 8 in file, 0-indexed = 7
    assert.equals(
      "This is a t.Log message - should be treated as hint, not error",
      hints[1].message
    )
    assert.equals(vim.diagnostic.severity.HINT, hints[1].severity)

    assert.equals(11, hints[2].line) -- line 12 in file, 0-indexed = 11
    assert.equals("Math works correctly", hints[2].message)
    assert.equals(vim.diagnostic.severity.HINT, hints[2].severity)
  end)

  it("should handle mixed output correctly", function()
    local test_output = {
      "go:5: Starting test execution",
      "go:10: panic: nil pointer dereference",
      "go:15: Test completed successfully",
      "go:20: FAIL: test assertion failed",
      "go:25: Debug information logged",
    }

    local hints = lib.diagnostics.extract_hints_from_output(test_output)

    -- Should only extract lines 5, 15, and 25 as hints
    assert.equals(3, #hints)
    assert.equals(4, hints[1].line) -- line 5, 0-indexed = 4
    assert.equals(14, hints[2].line) -- line 15, 0-indexed = 14
    assert.equals(24, hints[3].line) -- line 25, 0-indexed = 24
  end)
end)
