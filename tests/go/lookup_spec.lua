local _ = require("plenary")

local options = require("neotest-golang.options")
local lib = require("neotest-golang.lib")
local testify = require("neotest-golang.features.testify")

describe("Lookup", function()
  it("Generates tree replacement instructions", function()
    -- Arrange
    options.set({ testify_enabled = true }) -- enable testify
    local folderpath = vim.uv.cwd() .. "/tests/go"
    local filepaths = lib.find.go_test_filepaths(vim.uv.cwd())
    local expected_lookup = {
      [folderpath .. "/internal/positions/positions_test.go"] = {
        package = "positions",
        replacements = {},
      },
      [folderpath .. "/internal/subpackage/subpackage2/subpackage2_test.go"] = {
        package = "subpackage2",
        replacements = {},
      },
      [folderpath .. "/internal/subpackage/subpackage2/subpackage3/subpackage3_test.go"] = {
        package = "subpackage3",
        replacements = {},
      },
      [folderpath .. "/internal/testify/othersuite_test.go"] = {
        package = "testify",
        replacements = {
          OtherTestSuite = "TestOtherTestSuite",
        },
      },
      [folderpath .. "/internal/testify/positions_test.go"] = {
        package = "testify",
        replacements = {
          ExampleTestSuite = "TestExampleTestSuite",
          ExampleTestSuite2 = "TestExampleTestSuite2",
        },
      },
      [folderpath .. "/internal/x/xtest_blackbox_test.go"] = {
        package = "x_test",
        replacements = {},
      },
      [folderpath .. "/internal/x/xtest_whitebox_test.go"] = {
        package = "x",
        replacements = {},
      },
      [folderpath .. "/internal/testname/testname_test.go"] = {
        package = "testname",
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
