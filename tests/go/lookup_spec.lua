local _ = require("plenary")

local lib = require("neotest-golang.lib")
local options = require("neotest-golang.options")
local testify = require("neotest-golang.features.testify")

local function normalize_windows_path(path)
  return path:gsub("\\", "/")
end

describe("Lookup", function()
  it("Generates tree replacement instructions", function()
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
        package = "diagnostic_classification",
        replacements = {},
      },
      [folderpath .. "/internal/teststates/mixed/fail_skip_test.go"] = {
        package = "mixed",
        replacements = {},
      },
      [folderpath .. "/internal/teststates/passing/fail_skip_passing_test.go"] = {
        package = "passing",
        replacements = {},
      },
      [folderpath .. "/internal/teststates/skipping/fail_skip_skipping_test.go"] = {
        package = "skipping",
        replacements = {},
      },
      [folderpath .. "/internal/precision/treesitter_precision_test.go"] = {
        package = "precision",
        replacements = {},
      },
      [folderpath .. "/internal/positions/positions_test.go"] = {
        package = "positions",
        replacements = {},
      },
      [folderpath .. "/internal/outputsanitization/output_sanitization_test.go"] = {
        package = "outputsanitization",
        replacements = {},
      },
      [folderpath .. "/internal/nested/subpackage2/subpackage2_test.go"] = {
        package = "subpackage2",
        replacements = {},
      },
      [folderpath .. "/internal/nested/subpackage2/subpackage3/subpackage3_test.go"] = {
        package = "subpackage3",
        replacements = {},
      },
      [folderpath .. "/internal/testifysuites/othersuite_test.go"] = {
        package = "testifysuites",
        replacements = {
          OtherTestSuite = "TestOtherTestSuite",
        },
      },
      [folderpath .. "/internal/testifysuites/positions_test.go"] = {
        package = "testifysuites",
        replacements = {
          ExampleTestSuite = "TestExampleTestSuite",
          ExampleTestSuite2 = "TestExampleTestSuite2",
        },
      },
      [folderpath .. "/internal/specialchars/special_characters_test.go"] = {
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
      [folderpath .. "/internal/packaging/blackbox_test.go"] = {
        package = "packaging_test",
        replacements = {},
      },
      [folderpath .. "/internal/packaging/whitebox_test.go"] = {
        package = "packaging",
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
