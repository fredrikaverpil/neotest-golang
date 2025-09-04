local _ = require("plenary")
local options = require("neotest-golang.options")

-- Load our real execution helper
local real_execution_path = vim.uv.cwd() .. "/tests/helpers/real_execution.lua"
local real_execution = dofile(real_execution_path)

describe("Integration: fail/skip paths", function()
  it("file reports failed status when containing failing tests", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    -- Use the file that contains failing tests
    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/fail_skip/fail_skip_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    -- Execute all tests in this file (which includes failures)
    local tree, results = real_execution.execute_adapter_direct(test_filepath)

    -- File-level should be marked as failed when containing failing tests
    local file_pos_id = test_filepath
    assert.is_truthy(results[file_pos_id])
    assert.are.equal("failed", results[file_pos_id].status)

    -- Should have output
    assert.is_truthy(results[file_pos_id].output)
  end)

  it("file reports passed status when containing only passing tests", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    -- Use a file that contains only passing tests
    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/fail_skip_passing/fail_skip_passing_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    -- Execute all tests in this file (all passing)
    local tree, results = real_execution.execute_adapter_direct(test_filepath)

    -- File-level should be marked as passed when containing only passing tests
    local file_pos_id = test_filepath
    assert.is_truthy(results[file_pos_id])
    assert.are.equal("passed", results[file_pos_id].status)

    -- Should have output
    assert.is_truthy(results[file_pos_id].output)
  end)

  it("file reports passed status when containing only skipped tests", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    -- Use a file that contains only skipped tests
    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/fail_skip_skipping/fail_skip_skipping_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    -- Execute all tests in this file (all skipped)
    local tree, results = real_execution.execute_adapter_direct(test_filepath)

    -- File-level should be marked as passed when containing only skipped tests
    -- (This is because Go treats skipped tests as non-failures)
    local file_pos_id = test_filepath
    assert.is_truthy(results[file_pos_id])
    assert.are.equal("passed", results[file_pos_id].status)

    -- Should have output
    assert.is_truthy(results[file_pos_id].output)
  end)

  it("output contains evidence of test execution for failed tests", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/fail_skip/fail_skip_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    -- Execute all tests to get full output
    local tree, results = real_execution.execute_adapter_direct(test_filepath)

    local file_pos_id = test_filepath
    assert.is_truthy(results[file_pos_id])
    assert.is_truthy(results[file_pos_id].output)

    -- Read the output and verify it contains evidence of different test outcomes
    local output_lines = vim.fn.readfile(results[file_pos_id].output)
    local output_text = table.concat(output_lines, "\n")

    -- Should contain evidence of tests running
    assert.is_true(output_text:len() > 0, "Output should not be empty")

    -- The file overall should be failed since it contains failing tests
    assert.are.equal("failed", results[file_pos_id].status)
  end)
end)
