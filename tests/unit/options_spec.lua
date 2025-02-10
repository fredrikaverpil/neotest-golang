local options = require("neotest-golang.options")
local _ = require("plenary")

describe("Options are set up", function()
  it("With defaults", function()
    local expected_options = {
      runner = "go",
      go_test_args = {
        "-v",
        "-race",
        "-count=1",
      },
      go_list_args = {},
      gotestsum_args = { "--format=standard-verbose" },
      dap_go_opts = {},
      dap_mode = "dap-go",
      dap_manual_config = {},
      testify_enabled = false,
      testify_operand = "^(s|suite)$",
      testify_import_identifier = "^(suite)$",
      colorize_test_output = true,
      warn_test_name_dupes = true,
      warn_test_not_executed = true,
      log_level = vim.log.levels.WARN,
      sanitize_output = false,

      -- experimental
      dev_notifications = false,
    }
    options.setup()
    assert.are_same(expected_options, options.get())
  end)

  it("With non-defaults", function()
    local expected_options = {
      runner = "go",
      go_test_args = {
        "-v",
        "-race",
        "-count=1",
        "-parallel=1", -- non-default
      },
      go_list_args = {},
      gotestsum_args = { "--format=standard-verbose" },
      dap_go_opts = {},
      dap_mode = "dap-go",
      dap_manual_config = {},
      testify_enabled = false,
      testify_operand = "^(s|suite)$",
      testify_import_identifier = "^(suite)$",
      colorize_test_output = false,
      warn_test_name_dupes = true,
      warn_test_not_executed = true,
      log_level = vim.log.levels.WARN,
      sanitize_output = false,

      -- experimental
      dev_notifications = false,
    }
    options.setup(expected_options)
    assert.are_same(expected_options, options.get())
  end)

  it("With args as functions", function()
    local expected_options = {
      go_test_args = function()
        return {
          "-v",
          "-race",
          "-count=1",
          "-parallel=1",
        }
      end,
      go_list_args = function()
        return {}
      end,
      dap_go_opts = function()
        return {}
      end,
      dap_mode = function()
        return "dap-go"
      end,
      dap_manual_config = function()
        return {}
      end,
      testify_enabled = false,
      testify_operand = "^(s|suite)$",
      testify_import_identifier = "^(suite)$",
      colorize_test_output = true,
      warn_test_name_dupes = true,
      warn_test_not_executed = true,
      log_level = vim.log.levels.WARN,
      sanitize_output = false,

      -- experimental
      runner = "go",
      gotestsum_args = function()
        return { "--format=standard-verbose" }
      end,
      dev_notifications = false,
    }
    options.setup(expected_options)
    assert.are_same(expected_options, options.get())
  end)
end)
