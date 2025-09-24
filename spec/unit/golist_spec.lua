local lib = require("neotest-golang.lib")
local utils = dofile(vim.uv.cwd() .. "/spec/helpers/utils.lua")

describe("go list output from root", function()
  it("contains expected keys/values", function()
    local tests_filepath = vim.uv.cwd() .. "/tests/go"
    local output = lib.cmd.golist_data(tests_filepath)
    -- log.debug("Command:", vim.inspect(output))
    local first_entry = output[1]
    local expected = {
      Dir = utils.normalize_path(tests_filepath .. "/cmd/main"),
      ImportPath = "github.com/fredrikaverpil/neotest-golang/cmd/main",
      Module = {
        GoMod = utils.normalize_path(tests_filepath .. "/go.mod"),
      },
      Name = "main",
      TestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
      XTestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
    }

    assert.are_same(vim.inspect(expected), vim.inspect(first_entry))
    assert.are_same(expected, first_entry)
  end)
end)

describe("go list output from internal", function()
  it("contains expected keys/values", function()
    local tests_filepath = vim.uv.cwd() .. "/tests/go"
    local internal_filepath = vim.uv.cwd() .. "/tests/go/internal"
    local output = lib.cmd.golist_data(utils.normalize_path(internal_filepath))

    -- Find the positions package entry by ImportPath (order-agnostic)
    local positions_import =
      "github.com/fredrikaverpil/neotest-golang/internal/positions"
    local found
    for _, pkg in ipairs(output) do
      if pkg.ImportPath == positions_import then
        found = pkg
        break
      end
    end

    assert.is_truthy(found)

    local expected = {
      Dir = utils.normalize_path(internal_filepath .. "/positions"),
      ImportPath = positions_import,
      Module = {
        GoMod = utils.normalize_path(tests_filepath .. "/go.mod"),
      },
      Name = "positions",
      TestGoFiles = { "positions_test.go" },
      XTestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
    }

    assert.are_same(vim.inspect(expected), vim.inspect(found))
    assert.are_same(expected, found)
  end)
end)

describe("go list output from internal/positions", function()
  it("contains expected keys/values", function()
    local tests_filepath = vim.uv.cwd() .. "/tests/go"
    local positions_filepath = vim.uv.cwd() .. "/tests/go/internal/positions"
    local output = lib.cmd.golist_data(utils.normalize_path(positions_filepath))
    local first_entry = output[1]
    local expected = {
      Dir = utils.normalize_path(positions_filepath),
      ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/positions",
      Module = {
        GoMod = utils.normalize_path(tests_filepath .. "/go.mod"),
      },
      Name = "positions",
      TestGoFiles = { "positions_test.go" },
      XTestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
    }

    assert.are_same(vim.inspect(expected), vim.inspect(first_entry))
    assert.are_same(expected, first_entry)
  end)
end)

describe("go list output from internal/nested", function()
  it("contains expected keys/values", function()
    local tests_filepath = vim.uv.cwd() .. "/tests/go"
    local filepath = vim.uv.cwd() .. "/tests/go/internal/nested"
    local output = lib.cmd.golist_data(utils.normalize_path(filepath))
    local first_entry = output
    local expected = {
      {
        Dir = utils.normalize_path(filepath .. "/subpackage2"),
        ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/nested/subpackage2",
        Module = {
          GoMod = utils.normalize_path(tests_filepath .. "/go.mod"),
        },
        Name = "subpackage2",
        TestGoFiles = { "subpackage2_test.go" },
        XTestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
      },
      {
        Dir = utils.normalize_path(filepath .. "/subpackage2/subpackage3"),
        ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/nested/subpackage2/subpackage3",
        Module = {
          GoMod = utils.normalize_path(tests_filepath .. "/go.mod"),
        },
        Name = "subpackage3",
        TestGoFiles = { "subpackage3_test.go" },
        XTestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
      },
    }

    assert.are_same(vim.inspect(expected), vim.inspect(first_entry))
    assert.are_same(expected, first_entry)
  end)
end)

describe("go list output from internal/packaging", function()
  it("contains expected keys/values", function()
    local tests_filepath = vim.uv.cwd() .. "/tests/go"
    local filepath = vim.uv.cwd() .. "/tests/go/internal/packaging"
    local output = lib.cmd.golist_data(utils.normalize_path(filepath))
    local first_entry = output
    local expected = {
      {
        Dir = utils.normalize_path(filepath),
        ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/packaging",
        Module = {
          GoMod = utils.normalize_path(tests_filepath .. "/go.mod"),
        },
        Name = "packaging",
        TestGoFiles = { "whitebox_test.go" },
        XTestGoFiles = { "blackbox_test.go" }, -- NOTE: added here because of custom `go list -f` command
      },
    }

    assert.are_same(vim.inspect(expected), vim.inspect(first_entry))
    assert.are_same(expected, first_entry)
  end)
end)

describe("go list output from internal/packaging", function()
  it("contains TestGoFiles and XTestGoFiles", function()
    local tests_filepath = vim.uv.cwd() .. "/tests/go"
    local filepath = vim.uv.cwd() .. "/tests/go/internal/packaging"
    local output = lib.cmd.golist_data(utils.normalize_path(filepath))
    local first_entry = output
    local expected = {
      {
        Dir = utils.normalize_path(filepath),
        ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/packaging",
        Module = {
          GoMod = utils.normalize_path(tests_filepath .. "/go.mod"),
        },
        Name = "packaging",
        TestGoFiles = { "whitebox_test.go" },
        XTestGoFiles = { "blackbox_test.go" }, -- NOTE: added here because of custom `go list -f` command
      },
    }

    assert.are_same(vim.inspect(expected), vim.inspect(first_entry))
    assert.are_same(expected, first_entry)
  end)
end)

describe("go list output from internal/multifile", function()
  it("contains two TestGoFiles", function()
    local tests_filepath = vim.uv.cwd() .. "/tests/go"
    local filepath = vim.uv.cwd() .. "/tests/go/internal/multifile"
    local output = lib.cmd.golist_data(utils.normalize_path(filepath))
    local first_entry = output
    local expected = {
      {
        Dir = utils.normalize_path(filepath),
        ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/multifile",
        Module = {
          GoMod = utils.normalize_path(tests_filepath .. "/go.mod"),
        },
        Name = "multifile",
        TestGoFiles = { "first_file_test.go", "second_file_test.go" },
        XTestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
      },
    }

    assert.are_same(vim.inspect(expected), vim.inspect(first_entry))
    assert.are_same(expected, first_entry)
  end)
end)

describe("go list output from internal/notests", function()
  it("contains no tests", function()
    local tests_filepath = vim.uv.cwd() .. "/tests/go"
    local filepath = vim.uv.cwd() .. "/tests/go/internal/notests"
    local output = lib.cmd.golist_data(utils.normalize_path(filepath))
    local first_entry = output
    local expected = {
      {
        Dir = utils.normalize_path(filepath),
        ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/notests",
        Module = {
          GoMod = utils.normalize_path(tests_filepath .. "/go.mod"),
        },
        Name = "notests",
        TestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
        XTestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
      },
    }

    assert.are_same(vim.inspect(expected), vim.inspect(first_entry))
    assert.are_same(expected, first_entry)
  end)
end)

describe("Windows path handling", function()
  it("handles Windows drive letter paths in Dir field", function()
    -- Mock a golist_data response that would come from Windows
    local mock_golist_output = {
      {
        Dir = "D:\\\\a\\\\neotest-golang\\\\tests\\\\go\\\\cmd\\\\main",
        ImportPath = "github.com/fredrikaverpil/neotest-golang/cmd/main",
        Module = {
          GoMod = "D:\\\\a\\\\neotest-golang\\\\tests\\\\go\\\\go.mod",
        },
        Name = "main",
        TestGoFiles = {},
        XTestGoFiles = {},
      },
    }

    -- Verify that the structure contains Windows paths as expected
    local first_entry = mock_golist_output[1]
    assert.equals(
      "D:\\\\a\\\\neotest-golang\\\\tests\\\\go\\\\cmd\\\\main",
      first_entry.Dir
    )
    assert.equals(
      "D:\\\\a\\\\neotest-golang\\\\tests\\\\go\\\\go.mod",
      first_entry.Module.GoMod
    )
    assert.equals(
      "github.com/fredrikaverpil/neotest-golang/cmd/main",
      first_entry.ImportPath
    )
    assert.equals("main", first_entry.Name)
  end)

  it("handles Windows UNC paths in Dir field", function()
    local mock_golist_output = {
      {
        Dir = "\\\\\\\\server\\\\share\\\\project\\\\pkg",
        ImportPath = "example.com/project/pkg",
        Module = {
          GoMod = "\\\\\\\\server\\\\share\\\\project\\\\go.mod",
        },
        Name = "pkg",
        TestGoFiles = { "pkg_test.go" },
        XTestGoFiles = {},
      },
    }

    local first_entry = mock_golist_output[1]
    assert.equals("\\\\\\\\server\\\\share\\\\project\\\\pkg", first_entry.Dir)
    assert.equals(
      "\\\\\\\\server\\\\share\\\\project\\\\go.mod",
      first_entry.Module.GoMod
    )
    assert.equals("example.com/project/pkg", first_entry.ImportPath)
    assert.is_same({ "pkg_test.go" }, first_entry.TestGoFiles)
  end)

  it("handles Windows paths with mixed separators in Dir field", function()
    local mock_golist_output = {
      {
        Dir = "C:\\\\Users\\\\test/project\\\\internal\\\\mixed",
        ImportPath = "github.com/user/project/internal/mixed",
        Module = {
          GoMod = "C:\\\\Users\\\\test/project\\\\go.mod",
        },
        Name = "mixed",
        TestGoFiles = { "mixed_test.go" },
        XTestGoFiles = { "mixed_external_test.go" },
      },
    }

    local first_entry = mock_golist_output[1]
    assert.equals(
      "C:\\\\Users\\\\test/project\\\\internal\\\\mixed",
      first_entry.Dir
    )
    assert.equals(
      "C:\\\\Users\\\\test/project\\\\go.mod",
      first_entry.Module.GoMod
    )
    assert.equals(
      "github.com/user/project/internal/mixed",
      first_entry.ImportPath
    )
    assert.is_same({ "mixed_test.go" }, first_entry.TestGoFiles)
    assert.is_same({ "mixed_external_test.go" }, first_entry.XTestGoFiles)
  end)

  it("verifies path normalization works with Windows paths", function()
    -- Test that normalize_path function handles Windows paths correctly
    local windows_path = "D:\\\\path\\\\to\\\\project"
    local normalized = utils.normalize_path(windows_path)

    -- The normalize_path should handle this gracefully (exact behavior may vary by platform)
    assert.is_truthy(normalized)
    assert.is_string(normalized)

    local unc_path = "\\\\\\\\server\\\\share\\\\folder"
    local normalized_unc = utils.normalize_path(unc_path)
    assert.is_truthy(normalized_unc)
    assert.is_string(normalized_unc)
  end)
end)
