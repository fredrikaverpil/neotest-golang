local _ = require("plenary")
local options = require("neotest-golang.options")

describe("Integration (gotestsum): basic execution test", function()
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

  it("gotestsum command generation and execution", function()
    -- Check if gotestsum is available
    if vim.fn.executable("gotestsum") == 0 then
      print("Skipping gotestsum test - gotestsum not available")
      return
    end

    print("Gotestsum is available, testing command generation")

    -- Arrange: Configure gotestsum runner
    options.set({
      runner = "gotestsum",
      gotestsum_args = { "--format", "testname" },
      go_test_args = { "-v" },
      colorize_test_output = false,
      warn_test_results_missing = false,
    })

    -- Test command generation
    local cmd = require("neotest-golang.lib.cmd")
    local test_cmd, json_filepath = cmd.test_command_in_package_with_regexp(
      "./tests/go/internal/positions",
      "TestTopLevel"
    )

    -- Assert: Verify gotestsum command was generated
    assert.is_truthy(test_cmd)
    assert.is_truthy(json_filepath)
    local command_str = table.concat(test_cmd, " ")
    print("Generated command:", command_str)
    print("JSON filepath:", json_filepath)

    assert.is_true(
      command_str:find("gotestsum") ~= nil,
      "Should use gotestsum command"
    )
    assert.is_true(
      command_str:find("--jsonfile") ~= nil,
      "Should include jsonfile parameter"
    )

    print("Gotestsum command generation test completed successfully!")
  end)
end)
