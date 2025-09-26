local cgo = require("neotest-golang.lib.cgo")

describe("CGO validation utilities", function()
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
  end)

  describe("has_race_flag", function()
    it("returns true when -race flag is present", function()
      local args = { "-v", "-race", "-count=1" }
      assert.is_true(cgo.has_race_flag(args))
    end)

    it("returns false when -race flag is not present", function()
      local args = { "-v", "-count=1" }
      assert.is_false(cgo.has_race_flag(args))
    end)

    it("returns false for nil arguments", function()
      assert.is_false(cgo.has_race_flag(nil))
    end)

    it("returns false for empty arguments", function()
      assert.is_false(cgo.has_race_flag({}))
    end)

    it("finds -race among other flags", function()
      local args = { "-v", "-parallel=4", "-race", "-timeout=30s" }
      assert.is_true(cgo.has_race_flag(args))
    end)
  end)

  describe("is_cgo_enabled", function()
    it("returns true when CGO_ENABLED is not set (default)", function()
      vim.env.CGO_ENABLED = nil
      assert.is_true(cgo.is_cgo_enabled())
    end)

    it("returns true when CGO_ENABLED=1", function()
      vim.env.CGO_ENABLED = "1"
      assert.is_true(cgo.is_cgo_enabled())
    end)

    it("returns false when CGO_ENABLED=0", function()
      vim.env.CGO_ENABLED = "0"
      assert.is_false(cgo.is_cgo_enabled())
    end)

    it("returns false when CGO_ENABLED is set to any other value", function()
      vim.env.CGO_ENABLED = "false"
      assert.is_false(cgo.is_cgo_enabled())
    end)
  end)

  describe("validate_cgo_requirements", function()
    it("returns true when no -race flag is present", function()
      vim.env.CGO_ENABLED = "0" -- Even with CGO disabled
      local args = { "-v", "-count=1" }
      local is_valid, error_message = cgo.validate_cgo_requirements(args)
      assert.is_true(is_valid)
      assert.is_nil(error_message)
    end)

    it("returns error when -race flag is present but CGO_ENABLED=0", function()
      vim.env.CGO_ENABLED = "0"
      local args = { "-v", "-race", "-count=1" }
      local is_valid, error_message = cgo.validate_cgo_requirements(args)
      assert.is_false(is_valid)
      assert.is_not_nil(error_message)
      assert.is_true(
        string.match(error_message, "requires CGO to be enabled") ~= nil
      )
      assert.is_true(string.match(error_message, "CGO_ENABLED=0") ~= nil)
    end)

    it("includes documentation link in error message", function()
      vim.env.CGO_ENABLED = "0"
      local args = { "-race" }
      local is_valid, error_message = cgo.validate_cgo_requirements(args)
      assert.is_false(is_valid)
      assert.is_true(
        string.match(error_message, "config.md#go_test_args") ~= nil
      )
    end)

    it("works with CGO enabled and compiler available", function()
      vim.env.CGO_ENABLED = "1"
      local args = { "-v", "-race", "-count=1" }
      local is_valid, error_message = cgo.validate_cgo_requirements(args)
      -- This test result depends on whether a C compiler is actually available
      -- We just test that it doesn't fail due to CGO being disabled
      if not is_valid then
        -- If it fails, it should be due to missing compiler, not CGO
        assert.is_true(string.match(error_message, "C compiler") ~= nil)
        assert.is_false(string.match(error_message, "CGO_ENABLED=0") ~= nil)
      else
        assert.is_nil(error_message)
      end
    end)
  end)

  describe("get_go_c_compiler", function()
    it("returns a string or nil", function()
      local compiler = cgo.get_go_c_compiler()
      assert.is_true(type(compiler) == "string" or compiler == nil)
    end)
  end)

  describe("has_c_compiler", function()
    it("returns a boolean", function()
      local has_compiler = cgo.has_c_compiler()
      assert.is_true(type(has_compiler) == "boolean")
    end)
  end)
end)
