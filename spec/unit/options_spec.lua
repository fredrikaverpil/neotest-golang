local _ = require("plenary")
local options = require("neotest-golang.options")

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
      env = {},
      testify_enabled = false,
      testify_operand = "^(s|suite)$",
      testify_import_identifier = "^(suite)$",
      colorize_test_output = true,
      warn_test_name_dupes = true,
      log_level = vim.log.levels.WARN,
      sanitize_output = false,

      -- experimental
      dev_notifications = false,
      performance_monitoring = false,
    }
    options.setup()
    local actual_options = options.get()

    -- Check that runner_instance exists and is a table (object)
    assert.is_not_nil(actual_options.runner_instance)
    assert.is_table(actual_options.runner_instance)

    -- Remove runner_instance from comparison since it's an object
    local actual_for_comparison = vim.deepcopy(actual_options)
    actual_for_comparison.runner_instance = nil

    assert.are_same(expected_options, actual_for_comparison)
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
      env = {},
      testify_enabled = false,
      testify_operand = "^(s|suite)$",
      testify_import_identifier = "^(suite)$",
      colorize_test_output = false,
      warn_test_name_dupes = true,
      log_level = vim.log.levels.WARN,
      sanitize_output = false,

      -- experimental
      dev_notifications = false,
      performance_monitoring = false,
    }
    options.setup(expected_options)
    local actual_options = options.get()

    -- Check that runner_instance exists and is a table (object)
    assert.is_not_nil(actual_options.runner_instance)
    assert.is_table(actual_options.runner_instance)

    -- Remove runner_instance from comparison since it's an object
    local actual_for_comparison = vim.deepcopy(actual_options)
    actual_for_comparison.runner_instance = nil

    assert.are_same(expected_options, actual_for_comparison)
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
      env = function()
        return {}
      end,
      testify_enabled = false,
      testify_operand = "^(s|suite)$",
      testify_import_identifier = "^(suite)$",
      colorize_test_output = true,
      warn_test_name_dupes = true,
      log_level = vim.log.levels.WARN,
      sanitize_output = false,

      -- experimental
      runner = "go",
      gotestsum_args = function()
        return { "--format=standard-verbose" }
      end,
      dev_notifications = false,
      performance_monitoring = false,
    }
    options.setup(expected_options)
    local actual_options = options.get()

    -- Check that runner_instance exists and is a table (object)
    assert.is_not_nil(actual_options.runner_instance)
    assert.is_table(actual_options.runner_instance)

    -- Remove runner_instance from comparison since it's an object
    local actual_for_comparison = vim.deepcopy(actual_options)
    actual_for_comparison.runner_instance = nil

    assert.are_same(expected_options, actual_for_comparison)
  end)
end)
