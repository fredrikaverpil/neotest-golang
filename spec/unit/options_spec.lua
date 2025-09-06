local _ = require("plenary")
local options = require("neotest-golang.options")

describe("Options are set up", function()
  it("With defaults", function()
    -- Reset ALL options to true defaults (not partial setup that might miss some fields)
    options.setup({
      runner = "go",
      go_test_args = { "-v", "-race", "-count=1" },
      gotestsum_args = { "--format=standard-verbose" },
      go_list_args = {},
      dap_go_opts = {},
      dap_mode = "dap-go",
      dap_manual_config = {},
      env = {},
      testify_enabled = false,
      testify_operand = "^(s|suite)$",
      testify_import_identifier = "^(suite)$",
      colorize_test_output = true,
      warn_test_name_dupes = true,
      warn_test_not_executed = true,
      warn_test_results_missing = true,
      log_level = vim.log.levels.WARN,
      sanitize_output = false,
      dev_notifications = false,
    })

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
      env = {},
      testify_enabled = false,
      testify_operand = "^(s|suite)$",
      testify_import_identifier = "^(suite)$",
      colorize_test_output = true,
      warn_test_name_dupes = true,
      warn_test_not_executed = true,
      warn_test_results_missing = true,
      log_level = vim.log.levels.WARN,
      sanitize_output = false,

      dev_notifications = false,
    }
    assert.are_same(expected_options, options.get())
  end)

  it("With non-defaults", function()
    -- First reset to full defaults, then override specific fields
    options.setup({
      runner = "go",
      go_test_args = { "-v", "-race", "-count=1", "-parallel=1" }, -- Override this one
      gotestsum_args = { "--format=standard-verbose" },
      go_list_args = {},
      dap_go_opts = {},
      dap_mode = "dap-go",
      dap_manual_config = {},
      env = {},
      testify_enabled = false,
      testify_operand = "^(s|suite)$",
      testify_import_identifier = "^(suite)$",
      colorize_test_output = true,
      warn_test_name_dupes = true,
      warn_test_not_executed = true,
      warn_test_results_missing = true,
      log_level = vim.log.levels.WARN,
      sanitize_output = false,
      dev_notifications = false,
    })

    local expected_options = {
      runner = "go",
      go_test_args = {
        "-v",
        "-race",
        "-count=1",
        "-parallel=1",
      },
      go_list_args = {},
      gotestsum_args = { "--format=standard-verbose" },
      dap_go_opts = {},
      dap_mode = "dap-go",
      dap_manual_config = {},
      env = {},
      testify_enabled = false,
      testify_operand = "^(s|suite)$",
      testify_import_identifier = "^(suite)$",
      colorize_test_output = true,
      warn_test_name_dupes = true,
      warn_test_not_executed = true,
      warn_test_results_missing = true,
      log_level = vim.log.levels.WARN,
      sanitize_output = false,

      dev_notifications = false,
    }
    assert.are_same(expected_options, options.get())
  end)
end)
