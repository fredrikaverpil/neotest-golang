local options = require("neotest-golang.options")

describe("Options are set up", function()
  it("With defaults", function()
    local expected_options = {
      dap_go_enabled = false,
      dap_go_opts = {},
      go_test_args = {
        "-v",
        "-race",
        "-count=1",
        "-timeout=60s",
      },
    }
    options.setup()
    assert.are_same(expected_options, options.get())
  end)

  it("With non-defaults", function()
    local expected_options = {
      dap_go_enabled = false,
      dap_go_opts = {},
      go_test_args = {
        "-v",
        "-race",
        "-count=1",
        "-parallel=1",
        "-timeout=60s",
      },
    }
    options.setup(expected_options)
    assert.are_same(expected_options, options.get())
  end)
end)
