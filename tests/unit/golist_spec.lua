local _ = require("plenary")

local lib = require("neotest-golang.lib")

describe("go list output", function()
  it("contains expected keys/values", function()
    local tests_filepath = vim.loop.cwd() .. "/tests/go"
    local output = lib.cmd.golist_data(tests_filepath)
    local first_entry = output[1]
    local expected = {

      Deps = {
        "cmp",
        "errors",
        "fmt",
        "internal/abi",
        "internal/bytealg",
        "internal/chacha8rand",
        "internal/coverage/rtcov",
        "internal/cpu",
        "internal/fmtsort",
        "internal/goarch",
        "internal/godebugs",
        "internal/goexperiment",
        "internal/goos",
        "internal/itoa",
        "internal/oserror",
        "internal/poll",
        "internal/race",
        "internal/reflectlite",
        "internal/safefilepath",
        "internal/syscall/execenv",
        "internal/syscall/unix",
        "internal/testlog",
        "internal/unsafeheader",
        "io",
        "io/fs",
        "math",
        "math/bits",
        "os",
        "path",
        "reflect",
        "runtime",
        "runtime/internal/atomic",
        "runtime/internal/math",
        "runtime/internal/sys",
        "slices",
        "sort",
        "strconv",
        "sync",
        "sync/atomic",
        "syscall",
        "time",
        "unicode",
        "unicode/utf8",
        "unsafe",
      },
      Dir = tests_filepath,
      GoFiles = { "main.go" },
      ImportPath = "github.com/fredrikaverpil/neotest-golang",
      Imports = { "fmt" },
      Match = { "./..." },
      Module = {
        Dir = tests_filepath,
        GoMod = tests_filepath .. "/go.mod",
        GoVersion = "1.23.1",
        Main = true,
        Path = "github.com/fredrikaverpil/neotest-golang",
      },
      Name = "main",
      Root = tests_filepath,
      Stale = true,
      StaleReason = "build ID mismatch",
      Target = "/Users/fredrik/go/bin/neotest-golang",
      TestGoFiles = { "positions_test.go", "testname_test.go" },
      TestImports = { "os", "testing" },
    }

    -- ignored keys, as they might differ between OS/CI/platforms/too often
    expected.Module.GoVersion = nil
    first_entry.Module.GoVersion = nil
    expected.Deps = nil
    first_entry.Deps = nil
    expected.StaleReason = nil
    first_entry.StaleReason = nil
    expected.Target = nil
    first_entry.Target = nil

    assert.are_same(vim.inspect(expected), vim.inspect(first_entry))
    assert.are_same(expected, first_entry)
  end)
end)
