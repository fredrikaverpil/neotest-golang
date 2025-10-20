local _ = require("plenary")
local options = require("neotest-golang.options")
local path = require("neotest-golang.lib.path")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Integration: testify othersuite test", function()
  -- SKIPPED: This test file only has a suite function with no methods
  -- Since cross-file support was removed, there are no tests to run
  -- The integration test framework doesn't handle this edge case well
  pending(
    "file with only suite function and no methods shows no runnable tests (cross-file support removed)",
    function()
      -- ===== ARRANGE =====
      local test_options = options.get()
      test_options.runner = "gotestsum"
      test_options.testify_enabled = true
      options.set(test_options)

      local position_id = vim.uv.cwd()
        .. "/tests/features/internal/testifysuites/othersuite_test.go"
      position_id = path.normalize_path(position_id)

      -- ===== ACT =====
      -- This file only contains TestOtherTestSuite function but no test methods
      -- Methods are in other files, and cross-file support was removed
      -- Therefore, the adapter should find no tests to run

      ---@type AdapterExecutionResult
      local got = integration.execute_adapter_direct(position_id)

      -- ===== ASSERT =====
      -- Verify that the command indicates no tests found
      assert.is_not_nil(got.run_spec)
      assert.is_not_nil(got.run_spec.command)

      -- The command should be an "echo" message indicating no tests
      -- (This is the adapter's way of handling files with no runnable tests)
      assert.are.equal("echo", got.run_spec.command[1])

      -- Verify the tree exists but has no test children (only file node)
      assert.is_not_nil(got.tree)
      local tree_data = got.tree:data()
      assert.are.equal("file", tree_data.type)
      assert.are.equal(position_id, tree_data.id)
    end
  )
end)
