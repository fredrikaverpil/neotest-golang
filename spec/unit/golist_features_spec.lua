local lib = require("neotest-golang.lib")
local path = require("neotest-golang.lib.path")

describe("go list output from features root", function()
  it("contains expected keys/values", function()
    local features_filepath = vim.uv.cwd() .. "/tests/features"
    local output = lib.cmd.golist_data(features_filepath)

    -- The output should contain packages from the features directory
    assert.is_truthy(output)
    assert.is_table(output)
    assert.is_true(#output > 0)

    -- Find testifysuites package
    local testifysuites_import =
      "github.com/fredrikaverpil/neotest-golang/tests/features/internal/testifysuites"
    local testifysuites_pkg
    for _, pkg in ipairs(output) do
      if pkg.ImportPath == testifysuites_import then
        testifysuites_pkg = pkg
        break
      end
    end

    assert.is_truthy(testifysuites_pkg)
    assert.are_same(testifysuites_import, testifysuites_pkg.ImportPath)
    assert.are_same("testifysuites", testifysuites_pkg.Name)
    assert.are_same(
      path.normalize_path(features_filepath .. "/go.mod"),
      testifysuites_pkg.Module.GoMod
    )
  end)
end)

describe("go list output from features/internal", function()
  it("contains expected keys/values", function()
    local features_filepath = vim.uv.cwd() .. "/tests/features"
    local internal_filepath = vim.uv.cwd() .. "/tests/features/internal"
    local output = lib.cmd.golist_data(path.normalize_path(internal_filepath))

    -- Find the testifysuites package entry by ImportPath (order-agnostic)
    local testifysuites_import =
      "github.com/fredrikaverpil/neotest-golang/tests/features/internal/testifysuites"
    local found
    for _, pkg in ipairs(output) do
      if pkg.ImportPath == testifysuites_import then
        found = pkg
        break
      end
    end

    assert.is_truthy(found)

    local expected = {
      Dir = path.normalize_path(internal_filepath .. "/testifysuites"),
      ImportPath = testifysuites_import,
      Module = {
        GoMod = path.normalize_path(features_filepath .. "/go.mod"),
      },
      Name = "testifysuites",
      TestGoFiles = {
        "diagnostics_test.go",
        "othersuite_test.go",
        "positions_test.go",
        "regression_test.go",
        "subtest_test.go",
      },
      XTestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
    }

    assert.are_same(vim.inspect(expected), vim.inspect(found))
    assert.are_same(expected, found)
  end)
end)

describe("go list output from features/internal/testifysuites", function()
  it("contains expected keys/values", function()
    local features_filepath = vim.uv.cwd() .. "/tests/features"
    local testifysuites_filepath = vim.uv.cwd()
      .. "/tests/features/internal/testifysuites"
    local output =
      lib.cmd.golist_data(path.normalize_path(testifysuites_filepath))
    local first_entry = output[1]
    local expected = {
      Dir = path.normalize_path(testifysuites_filepath),
      ImportPath = "github.com/fredrikaverpil/neotest-golang/tests/features/internal/testifysuites",
      Module = {
        GoMod = path.normalize_path(features_filepath .. "/go.mod"),
      },
      Name = "testifysuites",
      TestGoFiles = {
        "diagnostics_test.go",
        "othersuite_test.go",
        "positions_test.go",
        "regression_test.go",
        "subtest_test.go",
      },
      XTestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
    }

    assert.are_same(vim.inspect(expected), vim.inspect(first_entry))
    assert.are_same(expected, first_entry)
  end)
end)

describe("go list output from features/internal/outputsanitization", function()
  it("contains expected keys/values", function()
    local features_filepath = vim.uv.cwd() .. "/tests/features"
    local outputsanitization_filepath = vim.uv.cwd()
      .. "/tests/features/internal/outputsanitization"
    local output =
      lib.cmd.golist_data(path.normalize_path(outputsanitization_filepath))
    local first_entry = output[1]
    local expected = {
      Dir = path.normalize_path(outputsanitization_filepath),
      ImportPath = "github.com/fredrikaverpil/neotest-golang/tests/features/internal/outputsanitization",
      Module = {
        GoMod = path.normalize_path(features_filepath .. "/go.mod"),
      },
      Name = "outputsanitization",
      TestGoFiles = { "output_sanitization_test.go" },
      XTestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
    }

    assert.are_same(vim.inspect(expected), vim.inspect(first_entry))
    assert.are_same(expected, first_entry)
  end)
end)
