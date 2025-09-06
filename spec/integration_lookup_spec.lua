local _ = require("plenary")

local lib = require("neotest-golang.lib")
local options = require("neotest-golang.options")
local testify = require("neotest-golang.features.testify")

local function normalize_windows_path(path)
  return path:gsub("\\", "/")
end

describe("Lookup", function()
  it("Generates tree replacement instructions", function()
    -- Save original testify setting
    local original_options = options.get()
    local original_testify_enabled = original_options.testify_enabled
    
    -- Arrange
    options.set({ testify_enabled = true }) -- enable testify
    local folderpath = vim.uv.cwd() .. "/tests/go"
    if vim.fn.has("win32") == 1 then
      folderpath = normalize_windows_path(folderpath)
    end
    local filepaths = lib.find.go_test_filepaths(vim.uv.cwd())
    if vim.fn.has("win32") == 1 then
      for i, filepath in ipairs(filepaths) do
        filepaths[i] = normalize_windows_path(filepath)
      end
    end
    local expected_lookup = {
      [folderpath .. "/internal/diagnostics/diagnostics_test.go"] = {
        package = "diagnostics",
        replacements = {},
      },
      [folderpath .. "/internal/behaviors/mixed/fail_skip_test.go"] = {
        package = "mixed",
        replacements = {},
      },
      [folderpath .. "/internal/behaviors/passing/fail_skip_passing_test.go"] = {
        package = "passing",
        replacements = {},
      },
      [folderpath .. "/internal/behaviors/skipping/fail_skip_skipping_test.go"] = {
        package = "skipping",
        replacements = {},
      },
      [folderpath .. "/internal/precision/precision_test.go"] = {
        package = "precision",
        replacements = {},
      },
      [folderpath .. "/internal/positions/positions_test.go"] = {
        package = "positions",
        replacements = {},
      },
      [folderpath .. "/internal/sanitization/sanitization_test.go"] = {
        package = "sanitization",
        replacements = {},
      },
      [folderpath .. "/internal/nested_packages/subpackage2/subpackage2_test.go"] = {
        package = "subpackage2",
        replacements = {},
      },
      [folderpath .. "/internal/nested_packages/subpackage2/subpackage3/subpackage3_test.go"] = {
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
      [folderpath .. "/internal/specialchars/specialchars_test.go"] = {
        package = "specialchars",
        replacements = {},
      },
      [folderpath .. "/internal/multifile/first_file_test.go"] = {
        package = "multifile",
        replacements = {},
      },
      [folderpath .. "/internal/multifile/second_file_test.go"] = {
        package = "multifile",
        replacements = {},
      },
      [folderpath .. "/internal/naming/blackbox_test.go"] = {
        package = "naming_test",
        replacements = {},
      },
      [folderpath .. "/internal/naming/whitebox_test.go"] = {
        package = "naming",
        replacements = {},
      },
      [folderpath .. "/internal/envtest/envtest_test.go"] = {
        package = "envtest",
        replacements = {},
      },
      [folderpath .. "/internal/customtestify/custom_testify_test.go"] = {
        package = "customtestify",
        replacements = {},
      },
    }

    -- Act
    testify.lookup.initialize_lookup(filepaths) -- generate lookup

    -- Assert
    local lookup = testify.lookup.get_lookup()
    assert.are.same(vim.inspect(expected_lookup), vim.inspect(lookup))
    assert.are.same(expected_lookup, lookup)
    
    -- Cleanup: restore original testify setting
    options.set({ testify_enabled = original_testify_enabled })
  end)
end)
