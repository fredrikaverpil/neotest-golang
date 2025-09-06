local _ = require("plenary")
local options = require("neotest-golang.options")

describe("Integration (gotestsum): no hanging", function()
  local original_options

  before_each(function()
    -- Save original options
    original_options = vim.deepcopy(options.get())
  end)

  after_each(function()
    -- Reset options to original state
    if original_options then
      options.setup(original_options)
    end
  end)

  it("can configure gotestsum without hanging", function()
    -- Check if gotestsum is available
    if vim.fn.executable("gotestsum") == 0 then
      print("Skipping gotestsum test - gotestsum not available")
      return
    end

    -- This used to hang the entire test suite
    -- Test that gotestsum options can be set without hanging
    options.set({
      runner = "gotestsum",
      gotestsum_args = { "--format", "testname" },
      go_test_args = { "-v" },
      colorize_test_output = false,
      warn_test_results_missing = false,
    })

    -- Verify options were set correctly
    local current_options = options.get()
    assert(current_options.runner == "gotestsum", "Runner should be gotestsum")
    assert(
      current_options.gotestsum_args[1] == "--format",
      "First gotestsum arg should be --format"
    )
    assert(
      current_options.gotestsum_args[2] == "testname",
      "Second gotestsum arg should be testname"
    )

    -- Reset options to avoid affecting other tests
    options.set({ runner = "go" })
  end)
end)
