local lib = require("neotest-golang.lib")
local utils = dofile(vim.uv.cwd() .. "/tests/helpers/utils.lua")

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
