describe("t.Log hint detection", function()
  local lib = require("neotest-golang.lib")

  it("should identify t.Log messages as hints", function()
    local test_lines = {
      "    tlog_test.go:8: This is a t.Log message - should be treated as hint, not error",
      "    tlog_test.go:12: Math works correctly",
      "    tlog_test.go:17: Starting test with some logging",
    }

    for _, line in ipairs(test_lines) do
      local is_hint = lib.hint.is_test_log_hint(line, "tlog_test.go")
      assert.is_true(
        is_hint,
        "Expected line to be identified as hint: " .. line
      )
    end
  end)

  it("should identify t.Error messages as errors", function()
    local test_lines = {
      "    tlog_test.go:24: Expected 1+1 to equal 3, but it equals 2",
      "    tlog_test.go:15: panic: something went wrong",
      "    tlog_test.go:20: assertion failed: values don't match",
    }

    for _, line in ipairs(test_lines) do
      local is_hint = lib.hint.is_test_log_hint(line, "tlog_test.go")
      assert.is_false(
        is_hint,
        "Expected line to be identified as error: " .. line
      )
    end
  end)

  it("should extract hints from test output", function()
    local test_output = {
      "    tlog_test.go:8: This is a t.Log message - should be treated as hint, not error",
      "    tlog_test.go:12: Math works correctly",
      "    tlog_test.go:24: Expected 1+1 to equal 3, but it equals 2",
    }

    local hints =
      lib.hint.extract_hints_from_output(test_output, "tlog_test.go")

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
end)

