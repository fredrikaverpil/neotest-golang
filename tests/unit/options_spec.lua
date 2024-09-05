local options = require("neotest-golang.options")
local _ = require("plenary")

describe("Options are set up", function()
  it("With defaults", function()
    local expected_options = {
      go_test_args = {
        "-v",
        "-race",
        "-count=1",
      },
      dap_go_opts = {},
      testify_enabled = false,
      warn_test_name_dupes = true,
      warn_test_not_executed = true,

      -- experimental
      runner = "go",
      gotestsum_args = { "--format=standard-verbose" },
      dev_notifications = false,
    }
    options.setup()
    assert.are_same(expected_options, options.get())
  end)

  it("With non-defaults", function()
    local expected_options = {
      go_test_args = {
        "-v",
        "-race",
        "-count=1",
        "-parallel=1", -- non-default
      },
      dap_go_opts = {},
      testify_enabled = false,
      warn_test_name_dupes = true,
      warn_test_not_executed = true,

      -- experimental
      runner = "go",
      gotestsum_args = { "--format=standard-verbose" },
      dev_notifications = false,
    }
    options.setup(expected_options)
    assert.are_same(expected_options, options.get())
  end)
end)
