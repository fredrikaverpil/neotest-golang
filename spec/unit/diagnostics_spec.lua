local lib = require("neotest-golang.lib")

describe("parse_diagnostic_line", function()
  it("parses filename/line/message and sets severity", function()
    local cases = {
      {
        line = "go:123: This is a debug message",
        expected = {
          filename = "go",
          line_number = 123,
          message = "This is a debug message",
          severity = vim.diagnostic.severity.HINT,
        },
      },
      {
        line = "database_test.go:456: using emulator",
        expected = {
          filename = "database_test.go",
          line_number = 456,
          message = "using emulator",
          severity = vim.diagnostic.severity.HINT,
        },
      },
      {
        line = "  file_test.go:789: indented message",
        expected = {
          filename = "file_test.go",
          line_number = 789,
          message = "indented message",
          severity = vim.diagnostic.severity.HINT,
        },
      },
      {
        line = "go:42: panic: something went wrong",
        expected = {
          filename = "go",
          line_number = 42,
          message = "panic: something went wrong",
          severity = vim.diagnostic.severity.ERROR,
        },
      },
      { line = "invalid line format", expected = nil },
      { line = "=== RUN   TestSomething", expected = nil },
      { line = "", expected = nil },
    }

    for _, case in ipairs(cases) do
      local res = lib.diagnostics.parse_diagnostic_line(case.line)
      if case.expected then
        assert.is_not_nil(res, "Should parse: " .. case.line)
        assert.equals(case.expected.filename, res.filename)
        assert.equals(case.expected.line_number, res.line_number)
        assert.equals(case.expected.message, res.message)
        assert.equals(case.expected.severity, res.severity)
      else
        assert.is_nil(res, "Should not parse: " .. case.line)
      end
    end
  end)
end)

describe("is_hint_message", function()
  it("classifies hint vs error messages", function()
    local cases = {
      { message = "Debug information logged", expected = true },
      { message = "Test completed successfully", expected = true },
      { message = "using emulator from environment", expected = true },
      { message = "panic: nil pointer dereference", expected = false },
      { message = "assertion failed: values don't match", expected = false },
      { message = "expected 42 but got 24", expected = false },
      { message = "error: connection failed", expected = false },
      { message = "FAIL: test assertion failed", expected = false },
      { message = "runtime error: index out of range", expected = false },
    }

    for _, c in ipairs(cases) do
      local is_hint = lib.diagnostics.is_hint_message(c.message)
      assert.equals(c.expected, is_hint, "Message: " .. c.message)
    end
  end)
end)

describe("integration: stream classification", function()
  it("classifies a mixed stream and preserves 0-indexed lines", function()
    local lines = {
      "go:5: Starting test execution",
      "go:10: panic: nil pointer dereference",
      "go:15: Test completed successfully",
      "go:20: FAIL: test assertion failed",
      "go:25: Debug information logged",
      "database_test.go:30: using emulator from environment",
    }

    local results = {}
    for _, line in ipairs(lines) do
      local d = lib.diagnostics.parse_diagnostic_line(line)
      if d then
        table.insert(results, {
          line = d.line_number - 1,
          message = d.message,
          severity = d.severity,
        })
      end
    end

    assert.equals(6, #results)

    local hints, errors = {}, {}
    for _, r in ipairs(results) do
      if r.severity == vim.diagnostic.severity.HINT then
        table.insert(hints, r.line + 1) -- convert to 1-index to compare with inputs
      else
        table.insert(errors, r.line + 1)
      end
    end

    -- expect hints at 5, 15, 25, 30; errors at 10, 20
    assert.equals(4, #hints)
    assert.equals(2, #errors)
    assert.is_true(vim.tbl_contains(hints, 5))
    assert.is_true(vim.tbl_contains(hints, 15))
    assert.is_true(vim.tbl_contains(hints, 25))
    assert.is_true(vim.tbl_contains(hints, 30))
    assert.is_true(vim.tbl_contains(errors, 10))
    assert.is_true(vim.tbl_contains(errors, 20))

    -- sanity check first/last messages
    assert.equals("Starting test execution", results[1].message)
    assert.equals("using emulator from environment", results[#results].message)
  end)
end)

describe("process_diagnostics", function()
  it("filters diagnostics by test filename", function()
    local test_entry = {
      metadata = {
        position_id = "/abs/path/my_test.go::TestSomething",
        output_parts = {
          table.concat({
            "my_test.go:10: Starting test",
            "other_test.go:11: Should be ignored",
          }, "\n"),
          "  my_test.go:12: panic: boom",
          "go:13: some harness line",
        },
      },
    }

    local errs = lib.diagnostics.process_diagnostics(test_entry)

    assert.equals(2, #errs)

    local by_line = {}
    for _, e in ipairs(errs) do
      by_line[e.line] = e
    end

    assert.is_not_nil(by_line[9])
    assert.is_not_nil(by_line[11])
    assert.equals("Starting test", by_line[9].message)
    assert.equals(vim.diagnostic.severity.HINT, by_line[9].severity)
    assert.equals("panic: boom", by_line[11].message)
    assert.equals(vim.diagnostic.severity.ERROR, by_line[11].severity)
  end)

  it("deduplicates identical diagnostics across parts", function()
    local test_entry = {
      metadata = {
        position_id = "/abs/path/my_test.go::TestFoo",
        output_parts = {
          "my_test.go:20: the same",
          table.concat({
            "my_test.go:20: the same",
            "my_test.go:21: different",
          }, "\n"),
        },
      },
    }

    local errs = lib.diagnostics.process_diagnostics(test_entry)
    assert.equals(2, #errs)

    local lines = {}
    for _, e in ipairs(errs) do
      lines[e.line] = true
    end

    assert.is_true(lines[19])
    assert.is_true(lines[20])
  end)

  it(
    "includes diagnostics when filename cannot be determined from position_id",
    function()
      local test_entry = {
        metadata = {
          position_id = "github.com/foo/bar::TestX",
          output_parts = {
            "go:5: Start",
            "other_test.go:3: message",
          },
        },
      }

      local errs = lib.diagnostics.process_diagnostics(test_entry)

      assert.equals(2, #errs)

      local one_index_lines = {}
      for _, e in ipairs(errs) do
        table.insert(one_index_lines, e.line + 1)
      end

      assert.is_true(vim.tbl_contains(one_index_lines, 5))
      assert.is_true(vim.tbl_contains(one_index_lines, 3))
    end
  )
end)
