--- Integration tests for issue #482: testify suite name collisions across packages.
--- Verifies that when two packages have suite structs with the same name,
--- their test methods don't leak into each other's namespaces.

local _ = require("plenary")
local options = require("neotest-golang.options")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Testify suite name collisions", function()
  it("foo_test package shows only its own methods", function()
    -- Configure options for testify with gotestsum
    local test_options = options.get()
    test_options.runner = "gotestsum"
    test_options.testify_enabled = true
    options.set(test_options)

    local file_path = "./tests/features/internal/testifysuites/foo/foo_test.go"

    local result = integration.execute_adapter_direct(file_path)

    -- The tree should contain:
    -- - File position
    -- - Test_TestSuite/Test_FooFunc method (flat structure - no namespace)
    -- It should NOT contain Test_BarFunc from the bar_test package

    local tree_string = vim.inspect(result.tree)

    -- Should contain foo package's method
    assert.is_not_nil(
      tree_string:match("Test_FooFunc"),
      "Expected to find Test_FooFunc in foo package tree"
    )

    -- Should NOT contain bar package's method
    assert.is_nil(
      tree_string:match("Test_BarFunc"),
      "Did not expect to find Test_BarFunc in foo package tree"
    )
  end)

  it("bar_test package shows only its own methods", function()
    -- Configure options for testify with gotestsum
    local test_options = options.get()
    test_options.runner = "gotestsum"
    test_options.testify_enabled = true
    test_options.log_level = vim.log.levels.DEBUG
    options.set(test_options)

    local file_path = "./tests/features/internal/testifysuites/bar/bar_test.go"

    local result = integration.execute_adapter_direct(file_path)

    -- The tree should contain:
    -- - File position
    -- - Test_TestSuite/Test_BarFunc method (flat structure - no namespace)
    -- It should NOT contain Test_FooFunc from the foo_test package

    local tree_string = vim.inspect(result.tree)

    -- Should contain bar package's method
    assert.is_not_nil(
      tree_string:match("Test_BarFunc"),
      "Expected to find Test_BarFunc in bar package tree"
    )

    -- Should NOT contain foo package's method
    assert.is_nil(
      tree_string:match("Test_FooFunc"),
      "Did not expect to find Test_FooFunc in bar package tree"
    )
  end)

  it("foo package test executes successfully", function()
    -- Configure options for testify with gotestsum
    local test_options = options.get()
    test_options.runner = "gotestsum"
    test_options.testify_enabled = true
    options.set(test_options)

    local file_path = "./tests/features/internal/testifysuites/foo/foo_test.go"

    local result = integration.execute_adapter_direct(file_path)

    assert.is_not_nil(result.tree, "Expected tree to be generated")

    -- Verify test execution produces valid results
    assert.is_not_nil(result.results, "Expected test results")
  end)

  it("bar package test executes successfully", function()
    -- Configure options for testify with gotestsum
    local test_options = options.get()
    test_options.runner = "gotestsum"
    test_options.testify_enabled = true
    options.set(test_options)

    local file_path = "./tests/features/internal/testifysuites/bar/bar_test.go"

    local result = integration.execute_adapter_direct(file_path)

    assert.is_not_nil(result.tree, "Expected tree to be generated")

    -- Verify test execution produces valid results
    assert.is_not_nil(result.results, "Expected test results")
  end)
end)
