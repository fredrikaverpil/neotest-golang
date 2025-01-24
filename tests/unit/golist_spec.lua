local log = require("plenary.log").new({
  plugin = "neotest-golang",
  level = "debug",
})

local lib = require("neotest-golang.lib")

local function convert_path_separators(path)
  if vim.fn.has("win32") == 1 then
    return path:gsub("/", "\\")
  end
  return path
end

describe("go list output from root", function()
  it("contains expected keys/values", function()
    local tests_filepath = vim.uv.cwd() .. "/tests/go"
    local output = lib.cmd.golist_data(tests_filepath)
    -- log.debug("Command:", vim.inspect(output))
    local first_entry = output[1]
    local expected = {
      Dir = convert_path_separators(tests_filepath .. "/cmd/main"),
      ImportPath = "github.com/fredrikaverpil/neotest-golang/cmd/main",
      Module = {
        GoMod = convert_path_separators(tests_filepath .. "/go.mod"),
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
    local output =
      lib.cmd.golist_data(convert_path_separators(internal_filepath))
    local first_entry = output[3]
    local expected = {
      Dir = convert_path_separators(internal_filepath .. "/positions"),
      ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/positions",
      Module = {
        GoMod = convert_path_separators(tests_filepath .. "/go.mod"),
      },
      Name = "positions",
      TestGoFiles = { "positions_test.go" },
      XTestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
    }

    assert.are_same(vim.inspect(expected), vim.inspect(first_entry))
    assert.are_same(expected, first_entry)
  end)
end)

describe("go list output from internal/positions", function()
  it("contains expected keys/values", function()
    local tests_filepath = vim.uv.cwd() .. "/tests/go"
    local positions_filepath = vim.uv.cwd() .. "/tests/go/internal/positions"
    local output =
      lib.cmd.golist_data(convert_path_separators(positions_filepath))
    local first_entry = output[1]
    local expected = {
      Dir = convert_path_separators(positions_filepath),
      ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/positions",
      Module = {
        GoMod = convert_path_separators(tests_filepath .. "/go.mod"),
      },
      Name = "positions",
      TestGoFiles = { "positions_test.go" },
      XTestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
    }

    assert.are_same(vim.inspect(expected), vim.inspect(first_entry))
    assert.are_same(expected, first_entry)
  end)
end)

describe("go list output from internal/subpackage", function()
  it("contains expected keys/values", function()
    local tests_filepath = vim.uv.cwd() .. "/tests/go"
    local filepath = vim.uv.cwd() .. "/tests/go/internal/subpackage"
    local output = lib.cmd.golist_data(convert_path_separators(filepath))
    local first_entry = output
    local expected = {
      {
        Dir = convert_path_separators(filepath .. "/subpackage2"),
        ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/subpackage/subpackage2",
        Module = {
          GoMod = convert_path_separators(tests_filepath .. "/go.mod"),
        },
        Name = "subpackage2",
        TestGoFiles = { "subpackage2_test.go" },
        XTestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
      },
      {
        Dir = convert_path_separators(filepath .. "/subpackage2/subpackage3"),
        ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/subpackage/subpackage2/subpackage3",
        Module = {
          GoMod = convert_path_separators(tests_filepath .. "/go.mod"),
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

describe("go list output from internal/x", function()
  it("contains expected keys/values", function()
    local tests_filepath = vim.uv.cwd() .. "/tests/go"
    local filepath = vim.uv.cwd() .. "/tests/go/internal/x"
    local output = lib.cmd.golist_data(convert_path_separators(filepath))
    local first_entry = output
    local expected = {
      {
        Dir = convert_path_separators(filepath),
        ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/x",
        Module = {
          GoMod = convert_path_separators(tests_filepath .. "/go.mod"),
        },
        Name = "x",
        TestGoFiles = { "xtest_whitebox_test.go" },
        XTestGoFiles = { "xtest_blackbox_test.go" }, -- NOTE: added here because of custom `go list -f` command
      },
    }

    assert.are_same(vim.inspect(expected), vim.inspect(first_entry))
    assert.are_same(expected, first_entry)
  end)
end)

describe("go list output from internal/x", function()
  it("contains TestGoFiles and XTestGoFiles", function()
    local tests_filepath = vim.uv.cwd() .. "/tests/go"
    local filepath = vim.uv.cwd() .. "/tests/go/internal/x"
    local output = lib.cmd.golist_data(convert_path_separators(filepath))
    local first_entry = output
    local expected = {
      {
        Dir = convert_path_separators(filepath),
        ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/x",
        Module = {
          GoMod = convert_path_separators(tests_filepath .. "/go.mod"),
        },
        Name = "x",
        TestGoFiles = { "xtest_whitebox_test.go" },
        XTestGoFiles = { "xtest_blackbox_test.go" }, -- NOTE: added here because of custom `go list -f` command
      },
    }

    assert.are_same(vim.inspect(expected), vim.inspect(first_entry))
    assert.are_same(expected, first_entry)
  end)
end)

describe("go list output from internal/two", function()
  it("contains two TestGoFiles", function()
    local tests_filepath = vim.uv.cwd() .. "/tests/go"
    local filepath = vim.uv.cwd() .. "/tests/go/internal/two"
    local output = lib.cmd.golist_data(convert_path_separators(filepath))
    local first_entry = output
    local expected = {
      {
        Dir = convert_path_separators(filepath),
        ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/two",
        Module = {
          GoMod = convert_path_separators(tests_filepath .. "/go.mod"),
        },
        Name = "two",
        TestGoFiles = { "one_test.go", "two_test.go" },
        XTestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
      },
    }

    assert.are_same(vim.inspect(expected), vim.inspect(first_entry))
    assert.are_same(expected, first_entry)
  end)
end)

describe("go list output from internal/notest", function()
  it("contains no tests", function()
    local tests_filepath = vim.uv.cwd() .. "/tests/go"
    local filepath = vim.uv.cwd() .. "/tests/go/internal/notest"
    local output = lib.cmd.golist_data(convert_path_separators(filepath))
    local first_entry = output
    local expected = {
      {
        Dir = convert_path_separators(filepath),
        ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/notest",
        Module = {
          GoMod = convert_path_separators(tests_filepath .. "/go.mod"),
        },
        Name = "notest",
        TestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
        XTestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
      },
    }

    assert.are_same(vim.inspect(expected), vim.inspect(first_entry))
    assert.are_same(expected, first_entry)
  end)
end)
