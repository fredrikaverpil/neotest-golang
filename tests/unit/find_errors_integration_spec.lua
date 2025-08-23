describe("find_errors integration", function()
  local process = require("neotest-golang.process")

  it(
    "should correctly differentiate hints from errors using streaming events",
    function()
      -- Initialize accumulator with empty errors array
      local test_id = "test_package::TestExample"
      local accum = {
        [test_id] = {
          status = "running",
          output = "",
          errors = {},
        },
      }

      -- Simulate streaming events with individual lines that contain go: patterns
      local streaming_events = {
        "go:8: This is a test log message\n",
        "go:12: Starting computation\n",
        "go:15: panic: something went wrong\n",
        "go:20: Debug info about test state\n",
        "go:25: Expected value 42, but got 24\n",
        "go:30: Cleanup complete\n",
      }

      -- Process each streaming event individually
      for _, event_output in ipairs(streaming_events) do
        accum = process.find_errors_in_event(accum, test_id, event_output)
      end

      local errors = accum[test_id].errors

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

  it("should handle streaming events with no go: patterns", function()
    local test_id = "test_package::TestSimple"
    local accum = {
      [test_id] = {
        status = "running",
        output = "",
        errors = {},
      },
    }

    -- Simulate streaming events with no go: patterns
    local streaming_events = {
      "=== RUN   TestSimple\n",
      "Running test...\n",
      "Test completed successfully\n",
      "--- PASS: TestSimple (0.00s)\n",
    }

    -- Process each streaming event individually
    for _, event_output in ipairs(streaming_events) do
      accum = process.find_errors_in_event(accum, test_id, event_output)
    end

    local errors = accum[test_id].errors

    -- Should have no diagnostic entries
    assert.equals(0, #errors)
  end)

  it(
    "should prevent duplicate errors when processing same event multiple times",
    function()
      local test_id = "test_package::TestDuplicate"
      local accum = {
        [test_id] = {
          status = "running",
          output = "",
          errors = {},
        },
      }

      local duplicate_event = "go:42: This error should only appear once\n"

      -- Process the same event multiple times
      accum = process.find_errors_in_event(accum, test_id, duplicate_event)
      accum = process.find_errors_in_event(accum, test_id, duplicate_event)
      accum = process.find_errors_in_event(accum, test_id, duplicate_event)

      local errors = accum[test_id].errors

      -- Should only have 1 error despite processing 3 times
      assert.equals(1, #errors)
      assert.equals(41, errors[1].line) -- 0-indexed, so line 42 becomes 41
      assert.equals("This error should only appear once", errors[1].message)
      assert.equals(vim.diagnostic.severity.HINT, errors[1].severity)
    end
  )
end)
