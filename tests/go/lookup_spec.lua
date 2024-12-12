local _ = require("plenary")

local options = require("neotest-golang.options")
local lib = require("neotest-golang.lib")
local testify = require("neotest-golang.features.testify")

describe("Lookup", function()
  it("Generates tree replacement instructions", function()
    -- Arrange
    options.set({ testify_enabled = true }) -- enable testify
    local folderpath = vim.loop.cwd() .. "/tests/go"
    local filepaths = lib.find.go_test_filepaths(vim.loop.cwd())
    local expected_lookup = {
      [folderpath .. "/positions_test.go"] = {
        package = "main",
        replacements = {},
      },
      [folderpath .. "/subpackage/subpackage2/subpackage2_test.go"] = {
        package = "subpackage2",
        replacements = {},
      },
      [folderpath .. "/subpackage/subpackage2/subpackage3/subpackage3_test.go"] = {
        package = "subpackage3",
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
          ExampleTestSuite2 = "TestExampleTestSuite2",
        },
      },
      [folderpath .. "/testname_test.go"] = {
        package = "main",
        replacements = {},
      },
      [folderpath .. "/x/xtest_blackbox_test.go"] = {
        package = "x_test",
        replacements = {},
      },
      [folderpath .. "/x/xtest_whitebox_test.go"] = {
        package = "x",
        replacements = {},
      },
    }

    -- Act
    testify.lookup.initialize_lookup(filepaths) -- generate lookup

    -- Assert
    local lookup = testify.lookup.get_lookup()
    assert.are.same(vim.inspect(expected_lookup), vim.inspect(lookup))
    assert.are.same(expected_lookup, lookup)
  end)
end)
