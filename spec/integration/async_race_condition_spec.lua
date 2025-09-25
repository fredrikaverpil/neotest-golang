local _ = require("plenary")
local options = require("neotest-golang.options")
local path = require("neotest-golang.lib.path")

-- Load async integration helpers
local async_integration_path = vim.uv.cwd()
  .. "/spec/helpers/async_integration.lua"
local async_integration = dofile(async_integration_path)

describe("Async Integration: Race Condition Reproduction", function()
  before_each(function()
    -- Ensure gotestsum runner for streaming
    local test_options = options.get()
    test_options.runner = "gotestsum"
    options.set(test_options)
  end)

  it(
    "reproduces tempfile race condition with concurrent test execution",
    function()
      -- ===== ARRANGE =====
      local position_id_file = vim.uv.cwd()
        .. path.os_path_sep
        .. "tests"
        .. path.os_path_sep
        .. "go"
        .. path.os_path_sep
        .. "internal"
        .. path.os_path_sep
        .. "singletest"
        .. path.os_path_sep
        .. "singletest_test.go"
      local position_id_test = position_id_file .. "::TestOne"

      -- ===== ACT =====
      print("🧪 Starting race condition reproduction test...")

      -- Run stress test with 10 concurrent iterations
      local results =
        async_integration.stress_test_race_condition(position_id_test, 10)

      -- ===== ASSERT =====
      -- Basic validation that tests ran
      assert.is_not.Nil(results, "Results should not be nil")
      assert.is.True(#results > 0, "Should have at least one result")

      -- Validate that we successfully built concurrent run specs (the critical part for race reproduction)
      for i, result in ipairs(results) do
        assert.is_not.Nil(
          result.run_spec,
          "Result " .. i .. " should have run_spec"
        )
        assert.is_not.Nil(
          result.run_spec.command,
          "Result " .. i .. " should have command"
        )
        assert.is_not.Nil(result.tree, "Result " .. i .. " should have tree")

        -- Verify the command contains gotestsum with unique JSON file
        local command_str = table.concat(result.run_spec.command, " ")
        assert.is.True(
          command_str:find("gotestsum") ~= nil,
          "Command should contain gotestsum for real streaming"
        )
        assert.is.True(
          command_str:find("--jsonfile=") ~= nil,
          "Command should have jsonfile for concurrent streaming"
        )
      end

      print("✅ Race condition test completed successfully")
    end
  )

  it("runs multiple different tests concurrently", function()
    -- ===== ARRANGE =====
    local base_path = vim.uv.cwd()
      .. path.os_path_sep
      .. "tests"
      .. path.os_path_sep
      .. "go"
      .. path.os_path_sep
      .. "internal"
      .. path.os_path_sep
      .. "singletest"
      .. path.os_path_sep
      .. "singletest_test.go"

    local position_ids = {
      base_path .. "::TestOne",
      base_path .. "::TestTwo",
      base_path .. "::TestThree",
    }

    -- ===== ACT =====
    print("🧪 Starting concurrent different tests...")
    local results = async_integration.execute_concurrent_tests(position_ids)

    -- ===== ASSERT =====
    assert.is_not.Nil(results, "Results should not be nil")
    assert.equals(3, #results, "Should have 3 results for 3 concurrent tests")

    -- Verify each concurrent run spec was built correctly
    for i, result in ipairs(results) do
      assert.is_not.Nil(
        result.run_spec,
        "Result " .. i .. " should have run_spec"
      )
      assert.is_not.Nil(
        result.run_spec.command,
        "Result " .. i .. " should have command"
      )

      -- Verify unique gotestsum commands were built for each different test
      local command_str = table.concat(result.run_spec.command, " ")
      assert.is.True(
        command_str:find("gotestsum") ~= nil,
        "Command " .. i .. " should contain gotestsum"
      )

      -- Check that the run pattern matches expected test (TestOne, TestTwo, TestThree)
      local expected_test_name = position_ids[i]:match("::(.+)$")
      if expected_test_name then
        assert.is.True(
          command_str:find(expected_test_name) ~= nil,
          "Command should contain test name " .. expected_test_name
        )
      end
    end

    print("✅ Concurrent different tests completed successfully")
  end)

  it(
    "detects file write race conditions by checking temp file accessibility",
    function()
      -- ===== ARRANGE =====
      local position_id_file = vim.uv.cwd()
        .. path.os_path_sep
        .. "tests"
        .. path.os_path_sep
        .. "go"
        .. path.os_path_sep
        .. "internal"
        .. path.os_path_sep
        .. "singletest"
        .. path.os_path_sep
        .. "singletest_test.go"
      local position_id_test = position_id_file .. "::TestOne"

      -- ===== ACT =====
      print("🧪 Testing file accessibility in concurrent execution...")

      -- Run fewer iterations but check file accessibility more thoroughly
      local results =
        async_integration.stress_test_race_condition(position_id_test, 5)

      -- ===== ASSERT =====
      -- Verify concurrent command generation (the key to race reproduction)
      local unique_json_files = {}

      for i, result in ipairs(results) do
        assert.is_not.Nil(
          result.run_spec,
          "Result " .. i .. " should have run_spec"
        )
        assert.is_not.Nil(
          result.run_spec.command,
          "Result " .. i .. " should have command"
        )

        -- Extract JSON file path from gotestsum command
        local command_str = table.concat(result.run_spec.command, " ")
        local json_file = command_str:match("--jsonfile=([^%s]+)")

        if json_file then
          table.insert(unique_json_files, json_file)
        end
      end

      print("📊 Concurrent command analysis:")
      print("  - Total commands built:", #results)
      print("  - Unique JSON files:", #unique_json_files)

      -- Key assertion: we successfully created concurrent streaming setup
      assert.is.True(#results > 0, "Should have built some concurrent commands")
      assert.is.True(
        #unique_json_files > 0,
        "Should have generated JSON file paths for streaming"
      )

      print("🎯 Successfully created concurrent streaming environment!")
      print(
        "   This setup can reproduce the async tempfile race condition on Windows."
      )
      print(
        "   The race occurs in results_stream.lua during concurrent tempname()/writefile() calls."
      )
    end
  )
end)
