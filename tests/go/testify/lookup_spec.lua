local _ = require("plenary")

local options = require("neotest-golang.options")
local testify = require("neotest-golang.features.testify")

describe("Lookup", function()
  it("Generates tree replacement instructions", function()
    -- Arrange
    options.set({ testify_enabled = true }) -- enable testify
    local folderpath = vim.loop.cwd() .. "/tests/go"
    local expected_lookup = {
      [folderpath .. "/positions_test.go"] = {
        package = "main",
        replacements = {},
      },
      [folderpath .. "/testify/othersuite_test.go"] = {
        package = "testify",
        replacements = {
          OtherTestSuite = "TestOtherTestSuite",
        },
      },
      [folderpath .. "/testify/positions_test.go"] = {
        package = "testify",
        replacements = {
          ExampleTestSuite = "TestExampleTestSuite",
        },
      },
      [folderpath .. "/testname_test.go"] = {
        package = "main",
        replacements = {},
      },
    }

    -- Act
    testify.lookup.generate() -- generate lookup

    -- Assert
    local lookup = testify.lookup.get()
    assert.are.same(vim.inspect(expected_lookup), vim.inspect(lookup))
    assert.are.same(expected_lookup, lookup)
  end)
end)
