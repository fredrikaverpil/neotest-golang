local _ = require("plenary")
local options = require("neotest-golang.options")

-- Load our real execution helper
local real_execution_path = vim.uv.cwd() .. "/spec/helpers/real_execution.lua"
local real_execution = dofile(real_execution_path)

describe("Integration: real test execution", function()
  it("executes and reports results for a test file", function()
    -- Arrange
    options.set({
      runner = "go",
      colorize_test_output = false,
      sanitize_output = false,
      warn_test_results_missing = false,
    })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/positions/positions_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    -- Act: Execute real test using our adapter directly
    local tree, results = real_execution.execute_adapter_direct(
      test_filepath,
      "TestTopLevel" -- Run only the simple test
    )

    -- Assert: Verify test tree was discovered
    assert.is_truthy(tree)
    local position_ids = real_execution.get_position_ids(tree)
    assert.is_true(#position_ids > 0, "Should discover test positions")

    -- Assert: File-level result exists and passed
    -- Note: Currently the adapter only returns file-level results when run directly
    -- This is expected because we're not using the streaming mechanism
    local file_pos_id = test_filepath
    real_execution.assert_test_status(results, file_pos_id, "passed")

    -- Assert: Output contains expected Go test results
    assert.is_truthy(results[file_pos_id].output, "Should have output file")
    local output_lines = vim.fn.readfile(results[file_pos_id].output)
    local output_text = table.concat(output_lines, "\n")

    -- Verify the output contains test execution evidence
    assert.is_true(output_text:len() > 0, "Output should not be empty")
    print("Test output length:", output_text:len(), "characters")
  end)

  it("executes tests with different runners", function()
    -- Test with regular go runner
    options.set({
      runner = "go",
      go_test_args = { "-v" },
      colorize_test_output = false,
    })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/specialchars/specialchars_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    -- Act: Execute test
    local tree, results = real_execution.execute_adapter_direct(test_filepath)

    -- Assert: Test file result
    real_execution.assert_test_status(results, test_filepath, "passed")
    assert.is_truthy(results[test_filepath].output, "Should have output")
  end)

  it("handles race condition testing", function()
    -- Test with race detection enabled
    options.set({
      runner = "go",
      go_test_args = { "-race", "-v" },
      colorize_test_output = false,
    })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/positions/positions_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    -- Act: Execute with race detection
    local tree, results, run_spec =
      real_execution.execute_adapter_direct(test_filepath)

    -- Assert: Command includes race flag
    local command_str = table.concat(run_spec.command, " ")
    assert.is_true(
      command_str:find("-race") ~= nil,
      "Command should include -race flag: " .. command_str
    )

    -- Assert: Tests still pass
    real_execution.assert_test_status(results, test_filepath, "passed")
  end)
end)
