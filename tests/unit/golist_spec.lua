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

    -- Find the position_discovery package entry by ImportPath (order-agnostic)
    local positions_import =
      "github.com/fredrikaverpil/neotest-golang/internal/position_discovery"
    local found
    for _, pkg in ipairs(output) do
      if pkg.ImportPath == positions_import then
        found = pkg
        break
      end
    end

    assert.is_truthy(found)

    local expected = {
      Dir = convert_path_separators(internal_filepath .. "/position_discovery"),
      ImportPath = positions_import,
      Module = {
        GoMod = convert_path_separators(tests_filepath .. "/go.mod"),
      },
      Name = "position_discovery",
      TestGoFiles = { "positions_test.go" },
      XTestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
    }

    assert.are_same(vim.inspect(expected), vim.inspect(found))
    assert.are_same(expected, found)
  end)
end)

describe("go list output from internal/position_discovery", function()
  it("contains expected keys/values", function()
    local tests_filepath = vim.uv.cwd() .. "/tests/go"
    local positions_filepath = vim.uv.cwd()
      .. "/tests/go/internal/position_discovery"
    local output =
      lib.cmd.golist_data(convert_path_separators(positions_filepath))
    local first_entry = output[1]
    local expected = {
      Dir = convert_path_separators(positions_filepath),
      ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/position_discovery",
      Module = {
        GoMod = convert_path_separators(tests_filepath .. "/go.mod"),
      },
      Name = "position_discovery",
      TestGoFiles = { "positions_test.go" },
      XTestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
    }

    assert.are_same(vim.inspect(expected), vim.inspect(first_entry))
    assert.are_same(expected, first_entry)
  end)
end)

describe("go list output from internal/nested_packages", function()
  it("contains expected keys/values", function()
    local tests_filepath = vim.uv.cwd() .. "/tests/go"
    local filepath = vim.uv.cwd() .. "/tests/go/internal/nested_packages"
    local output = lib.cmd.golist_data(convert_path_separators(filepath))
    local first_entry = output
    local expected = {
      {
        Dir = convert_path_separators(filepath .. "/subpackage2"),
        ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/nested_packages/subpackage2",
        Module = {
          GoMod = convert_path_separators(tests_filepath .. "/go.mod"),
        },
        Name = "subpackage2",
        TestGoFiles = { "subpackage2_test.go" },
        XTestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
      },
      {
        Dir = convert_path_separators(filepath .. "/subpackage2/subpackage3"),
        ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/nested_packages/subpackage2/subpackage3",
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

describe("go list output from internal/package_naming", function()
  it("contains expected keys/values", function()
    local tests_filepath = vim.uv.cwd() .. "/tests/go"
    local filepath = vim.uv.cwd() .. "/tests/go/internal/package_naming"
    local output = lib.cmd.golist_data(convert_path_separators(filepath))
    local first_entry = output
    local expected = {
      {
        Dir = convert_path_separators(filepath),
        ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/package_naming",
        Module = {
          GoMod = convert_path_separators(tests_filepath .. "/go.mod"),
        },
        Name = "package_naming",
        TestGoFiles = { "whitebox_test.go" },
        XTestGoFiles = { "blackbox_test.go" }, -- NOTE: added here because of custom `go list -f` command
      },
    }

    assert.are_same(vim.inspect(expected), vim.inspect(first_entry))
    assert.are_same(expected, first_entry)
  end)
end)

describe("go list output from internal/package_naming", function()
  it("contains TestGoFiles and XTestGoFiles", function()
    local tests_filepath = vim.uv.cwd() .. "/tests/go"
    local filepath = vim.uv.cwd() .. "/tests/go/internal/package_naming"
    local output = lib.cmd.golist_data(convert_path_separators(filepath))
    local first_entry = output
    local expected = {
      {
        Dir = convert_path_separators(filepath),
        ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/package_naming",
        Module = {
          GoMod = convert_path_separators(tests_filepath .. "/go.mod"),
        },
        Name = "package_naming",
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
    local output = lib.cmd.golist_data(convert_path_separators(filepath))
    local first_entry = output
    local expected = {
      {
        Dir = convert_path_separators(filepath),
        ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/multifile",
        Module = {
          GoMod = convert_path_separators(tests_filepath .. "/go.mod"),
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

describe("go list output from internal/no_tests_package", function()
  it("contains no tests", function()
    local tests_filepath = vim.uv.cwd() .. "/tests/go"
    local filepath = vim.uv.cwd() .. "/tests/go/internal/no_tests_package"
    local output = lib.cmd.golist_data(convert_path_separators(filepath))
    local first_entry = output
    local expected = {
      {
        Dir = convert_path_separators(filepath),
        ImportPath = "github.com/fredrikaverpil/neotest-golang/internal/no_tests_package",
        Module = {
          GoMod = convert_path_separators(tests_filepath .. "/go.mod"),
        },
        Name = "no_tests_package",
        TestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
        XTestGoFiles = {}, -- NOTE: added here because of custom `go list -f` command
      },
    }

    assert.are_same(vim.inspect(expected), vim.inspect(first_entry))
    assert.are_same(expected, first_entry)
  end)
end)
