______________________________________________________________________

## icon: material/cog

# Configuration

## Options

!!! tip "Recipes"
    See [the recipes](recipes.md) for usage examples of the below options.

### `runner`

Default value: `"go"`

This option defines the test execution runner, which by default is set to `"go"`
and will use `go test` to write test output to stdout.

!!! warning "Windows, Ubuntu Snaps"
    If you are on Windows or using Ubuntu snaps, you might want to set the runner
    to `"gotestsum"` and/or enable the [`sanitize_output`](#sanitize_output) option. See
    [this issue comment](https://github.com/fredrikaverpil/neotest-golang/issues/193#issuecomment-2362845806)
    for more details and continue reading.

To improve reliability, you can choose to set
[`gotestsum`](https://github.com/gotestyourself/gotestsum) as the test runner.
This tool allows the adapter to write test command output directly to a JSON
file without having to go through stdout.

Using `gotestsum` offers the following benefits:

- On certain platforms (such as Windows) or in certain terminals, there's a risk
  of ANSI codes or other characters being seemingly randomly inserted into the
  JSON test output. This can corrupt the data and cause problems with test
  output JSON decoding. Enabling `gotestsum` eliminates these issues, as the
  test output is then written directly to file.
- When you "attach" (in the Neotest summary window) to a running test, you'll
  see clean `go test` output instead of having to navigate through
  difficult-to-read JSON, as `gotestsum` is configured to _also_ output non-JSON
  test execution to stdout.

Gotestsum calls `go test` behind the scenes, so your `go_test_args`
configuration remains valid and will still apply.

??? example "Configure neotest-golang to use `gotestsum` as test runner"

````
Make the `gotestsum` command available via e.g.
[mason.nvim](https://github.com/williamboman/mason.nvim) or by running the
following in your shell:

```bash
go install gotest.tools/gotestsum@latest
```

Then add the required configuration:

```lua
local config = { -- Specify configuration
  runner = "gotestsum"
}
require("neotest").setup({
  adapters = {
    require("neotest-golang")(config), -- Apply configuration
  },
})
```
````

### `go_test_args`

Default value: `{ "-v", "-race", "-count=1" }`

Arguments to pass into `go test`. See `go help test`, `go help testflag`,
`go help build` for possible arguments.

The `-json` flag is mandatory and is always appended to `go test` automatically.

The value can also be passed in as a function.

!!! warning "CGO"
    The `-race` flag (in `go_test_args`) requires CGO to be enabled
    (`CGO_ENABLED=1` is the default) and a C compiler (such as GCC) to be
    installed. However, since Go 1.20, this is not a requirement on macOS. I have
    included the `-race` argument as default, as it provides good production
    defaults. See [this issue](https://github.com/golang/go/issues/9918) for more
    details.

### `gotestsum_args`

Default value: `{ "--format=standard-verbose" }`

Arguments to pass into `gotestsum`. Will only be applicable if
`runner = "gotestsum"`.

The value can also be passed in as a function.

### `go_list_args`

Default value: `{}`

Arguments to pass into `go list`. The main purpose of `go list` is to internally
translate between filepaths and Go package import paths.

A mandatory query is passed into the `-f` flag and is always appended
automatically, so that the necessary fields can be extracted.

The value can also be passed in as a function.

### `dap_mode`

Default value: `"dap-go"`

This option toggles between relying on
[leoluz/nvim-dap-go](https://github.com/leoluz/nvim-dap-go) to supply the delve
DAP configuration, or whether you wish to bring your own DAP configuration.

Set to `"manual"` for manual configuration.

The value can also be passed in as a function.

### `dap_go_opts`

Default value: `{}`

If using `dap_mode = "dap-go"`, you can supply dap-go with custom options.

The value can also be passed in as a function.

### `dap_manual_config`

Default value: `{}`

The configuration to apply if `dap_mode == "manual"`.

The value can also be passed in as a function.

### `env`

Default value: `{}`

A table of environment variables to set when running tests.

The value can also be passed in as a function.

??? example "Pass environment variables"

````
Provide environment variables like `table<string, string>`:

```lua
local config = { -- Specify configuration
  env = {
    TEST_VAR1 = "test1",
    TEST_VAR2 = "test2",
  },
}
require("neotest").setup({
  adapters = {
    require("neotest-golang")(config), -- Apply configuration
  },
})
```
````

!!! tip "Extra args"
    You can also pass in environment variables via Neotest's `extra_args` feature,
    see the [recipes](recipes.md) for more info.

### `filter_dirs`

!!! warning "Deprecated"
    This option is deprecated and will be removed in a future version.
    Use [`filter_dir_patterns`](#filter_dir_patterns) instead, which provides
    more powerful glob pattern matching.

Default value: `{ ".git", "node_modules", ".venv", "venv" }`

A list of directory names to exclude when searching for test files. These
directories will be filtered out during test discovery.

The value can also be passed in as a function.

??? example "Filter custom directories"

````
```lua
local config = { -- Specify configuration
  filter_dirs = {
    ".git",
    "node_modules",
    ".venv",
    "venv",
    "vendor",  -- Add custom directory
  },
}
require("neotest").setup({
  adapters = {
    require("neotest-golang")(config), -- Apply configuration
  },
})
```

Or use a function for dynamic filtering:

```lua
local config = {
  filter_dirs = function()
    return { ".git", "vendor", "third_party" }
  end,
}
require("neotest").setup({
  adapters = {
    require("neotest-golang")(config), -- Apply configuration
  },
})
```
````

### `filter_dir_patterns`

Default value: `{}`

A list of glob patterns to exclude when searching for test files. This option
provides more powerful filtering than `filter_dirs` by supporting glob patterns
that can match against directory paths (not just names).

Supported glob patterns follow the
[LSP 3.17 specification](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#documentFilter):

- `*` matches zero or more characters in a path segment
- `?` matches a single character in a path segment
- `**` matches any number of path segments, including none
- `{}` for grouping conditions (e.g., `**/*.{ts,js}`)
- `[]` for character ranges (e.g., `example.[0-9]`)

Patterns starting with `/` or a Windows drive letter (e.g., `C:\`) are treated
as absolute paths. Other patterns are matched against relative paths from the
project root.

The value can also be passed in as a function.

!!! note "Pattern behavior"
    Use `**/vendor` to match a directory named `vendor` at any depth.
    The pattern `**/vendor/**` would only match directories *inside* vendor,
    not vendor itself.

??? example "Filter with glob patterns"

````
```lua
local config = {
  filter_dir_patterns = {
    "**/vendor",        -- Any directory named 'vendor' at any depth
    "**/testdata",      -- Any directory named 'testdata' at any depth
    "third_party/**",   -- Everything inside 'third_party' at project root
  },
}
require("neotest").setup({
  adapters = {
    require("neotest-golang")(config),
  },
})
```
````

??? example "Filter specific nested paths"

````
Unlike `filter_dirs` which matches by name only, `filter_dir_patterns`
can target specific paths:

```lua
local config = {
  filter_dir_patterns = {
    "foo/baz",     -- Only matches ./foo/baz, not ./bar/baz
    "src/vendor",  -- Only matches ./src/vendor, not ./pkg/vendor
  },
}
require("neotest").setup({
  adapters = {
    require("neotest-golang")(config),
  },
})
```
````

??? example "Filter absolute paths (e.g., GOROOT)"

````
```lua
local config = {
  filter_dir_patterns = {
    "/usr/local/go/**",  -- Filter Go installation directory
  },
}
require("neotest").setup({
  adapters = {
    require("neotest-golang")(config),
  },
})
```
````

??? example "Use function for dynamic patterns"

````
```lua
local config = {
  filter_dir_patterns = function()
    -- Get GOROOT dynamically
    local goroot = vim.fn.system("go env GOROOT"):gsub("\n", "")
    return {
      "**/vendor",
      goroot .. "/**",
    }
  end,
}
require("neotest").setup({
  adapters = {
    require("neotest-golang")(config),
  },
})
```
````

### `testify_enabled`

Default value: `false`

Enable support for [testify](https://github.com/stretchr/testify) suites and
other testify related features, such as testify-specific diagnostics. Please
note that this feature requires `nvim-treesitter` (`main` branch).

!!! warning "Not enabled by default"
    This feature comes with some caveats and nuances, which is why it is not enabled
    by default. I advise you to only enable this if you need it.

    There are some real shenaningans going on behind the scenes to make this work.
    😅 First, an in-memory lookup of "receiver type-to-suite test function" will be
    created of all Go test files in your project. Then, the generated Neotest node
    tree is modified by mutating private attributes, so to prefix test IDs with the
    suite name (e.g. `SuiteName/TestMethod`).
    I'm personally a bit afraid of the maintenance burden of this feature... 🙈

!!! note "Table tests not supported"
    Right now, table tests are not supported for testify suites. This can be
    remedied by extending the treesitter queries. Feel free to dig in
    and open a PR!

### `testify_operand`

Default value: `"^(s|suite)$"`

Extend this regex value to support something other than e.g. `s.Run` or
`suite.Run` for running subtests.

??? example "Custom subtest operand"

````
If `x` is used as operand for the `Run` method, you must set this option
and extend the regex.

```go
func (x *TestSuite) TestFoo() {
    x.Run("foo", func() {
        ...
    })
}
```

```lua
opts = { testify_operand = "^(s|suite|x)$" }
```
````

### `testify_import_identifier`

Default value: `"^(suite)$"`

Extend this regex value if you use a custom import identifier.

??? example "Custom import identifier"

````
If `suite` is available under the import identifier `testifysuite`,
you need to set this option and extend the regex.

```go
import (
    testifysuite "github.com/stretchr/testify/suite"
)
```

```lua
opts = { testify_import_identifier = "^(suite|testifysuite)$" }
```
````

### `colorize_test_output`

Default value: `true`

Enable output color for `SUCCESS`, `FAIL`, and `SKIP` tests.

### `warn_test_name_dupes`

Default value: `true`

Warn about duplicate test names within the same Go package.

### `log_level`

Default value: `"vim.log.levels.WARN"`

Neotest-golang piggybacks on the Neotest logger but writes its own file. The
default log level is `WARN` but during troubleshooting you want to increase
this. See `:h vim.log.levels` for all levels.

??? example "Increasing the log level"

````
```lua
local config = {
    log_level = vim.log.levels.DEBUG, -- set log level
}

require("neotest").setup({
  adapters = {
    require("neotest-golang")(config), -- Apply configuration
  },
})
```

!!! warn "Do not forget to revert"

    Don't forget to revert back to `WARN` level once you are done troubleshooting,
    as the `DEBUG` level can degrade performance.
````

!!! tip "Convenience command"
    The neotest-golang logs can be opened using this convenient vim command:

    ```vim
    :exe 'edit' stdpath('log').'/neotest-golang.log'
    ```

    This usually corresponds to something like
    `~/.local/state/nvim/neotest-golang.log`.

### `sanitize_output`

Default value: `false`

Filter control characters and non-printable characters from test output.
Requires the [uga-rosa/utf8.nvim](https://github.com/uga-rosa/utf8.nvim)
library.

When tests write non-printable characters to stdout/stderr, they can cause
various issues like failing to write output to disk or UI rendering problems.
The `sanitize_output` option helps clean up such output by preserving UTF-8 and
replacing control characters with the Unicode replacement character (�).

This is particularly useful when:

- Tests write bytes to stdout/stderr.
- Test output contains terminal control sequences.
- Test output includes non-printable characters.

The sanitization preserves all regular printable characters including tabs,
newlines, and carriage returns.

??? example "Example config"

````
```diff
return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      { "nvim-treesitter/nvim-treesitter", branch = "main" },
-      "fredrikaverpil/neotest-golang", -- Installation
+      {
+        "fredrikaverpil/neotest-golang", -- Installation
+        version = "*",
+        dependencies = {
+          "uga-rosa/utf8.nvim", -- Additional dependency required
+        },
+      },
    },
    config = function()
      require("neotest").setup({
        adapters = {
-          require("neotest-golang"), -- Registration
+          require("neotest-golang")({ sanitize_output = true }), -- Registration
        },
      })
    end,
  },
}
```
````
