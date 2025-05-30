local _ = require("plenary")
local extra_args = require("neotest-golang.extra_args")
local lib = require("neotest-golang.lib")
local options = require("neotest-golang.options")

describe("Extra args", function()
  it("Can't be nil even if set to nil", function()
    extra_args.set(nil)
    assert.are.same({}, extra_args.get())
  end)

  it("Returns the arg that were previously set", function()
    extra_args.set({ "-foo", "-bar" })
    assert.are.same({ "-foo", "-bar" }, extra_args.get())
  end)

  it("Overrides options.go_test_args", function()
    extra_args.set({ go_test_args = { "-baz", "-qux" } })

    options.setup({ runner = "go", go_test_args = { "-foo", "-bar" } })
    local command, _ = lib.cmd.test_command({})
    assert.are.same({ "go", "test", "-json", "-baz", "-qux" }, command)

    options.setup({ runner = "gotestsum", go_test_args = { "-foo", "-bar" } })
    command, _ = lib.cmd.test_command({})
    -- This parameter, the jsonfile path, contains a random string, let's get rid of it
    table.remove(command, 2)
    assert.are.same(
      { "gotestsum", "--format=standard-verbose", "--", "-baz", "-qux" },
      command
    )
  end)

  it("Defaults to options.go_test_args", function()
    extra_args.set({})

    options.setup({ runner = "go", go_test_args = { "-foo", "-bar" } })
    local command, _ = lib.cmd.test_command({})
    assert.are.same({ "go", "test", "-json", "-foo", "-bar" }, command)

    options.setup({ runner = "gotestsum", go_test_args = { "-foo", "-bar" } })
    command, _ = lib.cmd.test_command({})
    -- This parameter, the jsonfile path, contains a random string, let's get rid of it
    table.remove(command, 2)
    assert.are.same(
      { "gotestsum", "--format=standard-verbose", "--", "-foo", "-bar" },
      command
    )
  end)
end)
