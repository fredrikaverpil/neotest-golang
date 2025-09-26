local _ = require("plenary")
local options = require("neotest-golang.options")
local path = require("neotest-golang.lib.path")

-- Load integration helpers
local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
local integration = dofile(integration_path)

describe("Integration: -race flag CGO validation", function()
  local original_env = {}

  before_each(function()
    -- Save original environment
    original_env = {
      CGO_ENABLED = vim.env.CGO_ENABLED,
    }
  end)

  after_each(function()
    -- Restore original environment
    for key, value in pairs(original_env) do
      vim.env[key] = value
    end

    -- Reset options to defaults
    options.setup({})
  end)

  it(
    "should work normally with default settings when GCC is available",
    function()
      -- ===== ARRANGE =====
      local test_options = options.get()
      test_options.runner = "gotestsum"
      -- Keep default go_test_args which includes -race
      options.set(test_options)

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

      -- Ensure CGO is enabled (default behavior)
      vim.env.CGO_ENABLED = nil -- Let it default to enabled

      -- ===== ACT & ASSERT =====
      -- This should succeed if GCC is available
      local success, result =
        pcall(integration.execute_adapter_direct, position_id_test)

      if success then
        -- GCC is available, test should pass normally
        assert.are.equal(0, result.strategy_result.code)
        assert.is_not_nil(result.results[position_id_test])
        assert.are.equal("passed", result.results[position_id_test].status)
      else
        -- GCC might not be available, check if error message is about CGO/GCC
        local error_msg = tostring(result)
        if
          string.match(error_msg, "requires a C compiler")
          or string.match(error_msg, "requires CGO")
        then
          -- This is expected if GCC is not available
          print(
            "Note: GCC not available on this system, which is expected for some environments"
          )
        else
          -- Some other error, re-raise it
          error(result)
        end
      end
    end
  )

  it("should fail early when -race is used with CGO_ENABLED=0", function()
    -- ===== ARRANGE =====
    local test_options = options.get()
    test_options.runner = "gotestsum"
    -- Keep default go_test_args which includes -race
    options.set(test_options)

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

    -- Disable CGO
    vim.env.CGO_ENABLED = "0"

    -- ===== ACT =====
    local success, result =
      pcall(integration.execute_adapter_direct, position_id_test)

    -- ===== ASSERT =====
    assert.is_false(
      success,
      "Expected test execution to fail due to CGO validation"
    )
    local error_msg = tostring(result)
    assert.is_true(
      string.match(error_msg, "requires CGO to be enabled") ~= nil,
      "Error should mention CGO requirement, got: " .. error_msg
    )
    assert.is_true(
      string.match(error_msg, "CGO_ENABLED=0") ~= nil,
      "Error should mention CGO_ENABLED=0, got: " .. error_msg
    )
    assert.is_true(
      string.match(error_msg, "config.md#go_test_args") ~= nil,
      "Error should include documentation link, got: " .. error_msg
    )
  end)

  it(
    "should work normally when -race is not used, regardless of CGO settings",
    function()
      -- ===== ARRANGE =====
      local test_options = options.get()
      test_options.runner = "gotestsum"
      -- Remove -race from go_test_args
      test_options.go_test_args = { "-v", "-count=1" }
      options.set(test_options)

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

      -- Disable CGO (should not matter since we're not using -race)
      vim.env.CGO_ENABLED = "0"

      -- ===== ACT =====
      local result = integration.execute_adapter_direct(position_id_test)

      -- ===== ASSERT =====
      -- Should succeed even with CGO disabled since we don't use -race
      assert.are.equal(0, result.strategy_result.code)
      assert.is_not_nil(result.results[position_id_test])
      assert.are.equal("passed", result.results[position_id_test].status)
    end
  )

  it("should work with custom go_test_args without -race", function()
    -- ===== ARRANGE =====
    local test_options = options.get()
    test_options.runner = "gotestsum"
    -- Custom args without -race
    test_options.go_test_args = { "-v", "-parallel=1", "-count=1" }
    options.set(test_options)

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

    -- Disable CGO (should not matter)
    vim.env.CGO_ENABLED = "0"

    -- ===== ACT =====
    local result = integration.execute_adapter_direct(position_id_test)

    -- ===== ASSERT =====
    assert.are.equal(0, result.strategy_result.code)
    assert.is_not_nil(result.results[position_id_test])
    assert.are.equal("passed", result.results[position_id_test].status)
  end)

  it("should handle function-based go_test_args with -race flag", function()
    -- ===== ARRANGE =====
    local test_options = options.get()
    test_options.runner = "gotestsum"
    -- Function that returns args with -race
    test_options.go_test_args = function()
      return { "-v", "-race", "-count=1" }
    end
    options.set(test_options)

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

    -- Disable CGO
    vim.env.CGO_ENABLED = "0"

    -- ===== ACT =====
    local success, result =
      pcall(integration.execute_adapter_direct, position_id_test)

    -- ===== ASSERT =====
    assert.is_false(
      success,
      "Expected test execution to fail due to CGO validation"
    )
    local error_msg = tostring(result)
    assert.is_true(
      string.match(error_msg, "requires CGO to be enabled") ~= nil,
      "Error should mention CGO requirement, got: " .. error_msg
    )
  end)

  it("should work with go test runner (not just gotestsum)", function()
    -- Note: This test verifies CGO validation works with the "go" runner
    -- However, the integration test framework requires gotestsum for streaming,
    -- so we test the validation logic directly instead

    -- ===== ARRANGE =====
    local cgo_lib = require("neotest-golang.lib.cgo")
    local test_options = options.get()
    test_options.runner = "go"
    -- Remove -race from go_test_args
    test_options.go_test_args = { "-v", "-count=1" }
    options.set(test_options)

    -- Disable CGO (should not matter since we're not using -race)
    vim.env.CGO_ENABLED = "0"

    -- ===== ACT =====
    -- Test the validation directly
    local is_valid, error_message =
      cgo_lib.validate_cgo_requirements(test_options.go_test_args)

    -- ===== ASSERT =====
    -- Should succeed because we don't have -race flag
    assert.is_true(is_valid, "Validation should succeed without -race flag")
    assert.is_nil(error_message, "Should not have an error message")

    -- Verify has_race_flag works correctly
    assert.is_false(
      cgo_lib.has_race_flag(test_options.go_test_args),
      "Should not detect -race flag"
    )
  end)

  it(
    "should fail early with go test runner when -race is used with CGO_ENABLED=0",
    function()
      -- Note: This test verifies CGO validation works with the "go" runner
      -- We test the validation logic directly by calling validate_cgo_requirements

      -- ===== ARRANGE =====
      local cgo_lib = require("neotest-golang.lib.cgo")

      -- Set up test args with -race
      local test_args = { "-v", "-race", "-count=1" }

      -- Disable CGO
      vim.env.CGO_ENABLED = "0"

      -- ===== ACT =====
      -- Test the validation directly
      local is_valid, error_message =
        cgo_lib.validate_cgo_requirements(test_args)

      -- ===== ASSERT =====
      assert.is_false(
        is_valid,
        "Expected validation to fail due to CGO_ENABLED=0 with -race flag"
      )
      assert.is_not_nil(error_message, "Should have an error message")
      assert.is_true(
        string.match(error_message, "requires CGO to be enabled") ~= nil,
        "Error should mention CGO requirement, got: " .. error_message
      )
      assert.is_true(
        string.match(error_message, "CGO_ENABLED=0") ~= nil,
        "Error should mention CGO_ENABLED=0, got: " .. error_message
      )
      assert.is_true(
        string.match(error_message, "config.md#go_test_args") ~= nil,
        "Error should include documentation link, got: " .. error_message
      )
    end
  )
end)
