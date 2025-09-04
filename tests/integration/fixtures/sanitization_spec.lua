local _ = require("plenary")
local options = require("neotest-golang.options")

-- Load real execution helper
local real_execution_path = vim.uv.cwd() .. "/tests/helpers/real_execution.lua"
local real_execution = dofile(real_execution_path)

describe("Integration: output_sanitization", function()
  it("discovers output sanitization test fixture", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/output_sanitization/output_sanitization_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    -- This test verifies that the output_sanitization fixture exists and can be discovered
    -- The fixture writes random binary data to stdout, which tests the sanitize_output option

    local adapter = require("neotest-golang")
    local nio = require("nio")
    local tree =
      nio.tests.with_async_context(adapter.discover_positions, test_filepath)

    assert.is_truthy(tree, "Should be able to discover test positions")

    -- Basic verification that we found the test structure
    local tree_list = tree:to_list()
    assert.is_true(#tree_list > 0, "Should discover test structure")

    -- Should find the test file
    local has_file_node = false
    for _, node in ipairs(tree_list) do
      if node.type == "file" then
        has_file_node = true
        break
      end
    end

    assert.is_true(
      has_file_node,
      "Should discover file structure for output sanitization test"
    )
  end)

  it("tests sanitize_output option functionality", function()
    -- Test with sanitize_output disabled (default)
    options.set({
      runner = "go",
      warn_test_results_missing = false,
      sanitize_output = false,
    })

    local test_filepath = vim.uv.cwd()
      .. "/tests/go/internal/output_sanitization/output_sanitization_test.go"
    test_filepath = real_execution.normalize_path(test_filepath)

    -- The key test: this fixture writes 1000 bytes of random binary data to stdout
    -- With sanitize_output = false, the adapter may have trouble processing this
    -- With sanitize_output = true, the adapter should handle it better

    local adapter = require("neotest-golang")
    local nio = require("nio")
    local tree =
      nio.tests.with_async_context(adapter.discover_positions, test_filepath)

    assert.is_truthy(
      tree,
      "Should discover positions even with binary output potential"
    )

    -- Now test with sanitize_output enabled
    options.set({
      runner = "go",
      warn_test_results_missing = false,
      sanitize_output = true,
    })

    local tree_sanitized =
      nio.tests.with_async_context(adapter.discover_positions, test_filepath)

    assert.is_truthy(
      tree_sanitized,
      "Should discover positions with sanitize_output enabled"
    )

    -- Both should work for discovery (the real test is during execution)
    local tree_list = tree_sanitized:to_list()
    assert.is_true(
      #tree_list > 0,
      "Should discover test structure with sanitization enabled"
    )
  end)
end)
