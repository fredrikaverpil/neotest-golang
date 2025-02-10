---
icon: material/cog
---

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

### `testify_enabled`

Default value: `false`

Enable support for [testify](https://github.com/stretchr/testify) suites.

!!! warning "Not enabled by default"

    This feature comes with some caveats and nuances, which is why it is not enabled
    by default. I advise you to only enable this if you need it.

    There are some real shenaningans going on behind the scenes to make this work.
    😅 First, an in-memory lookup of "receiver type-to-suite test function" will be
    created of all Go test files in your project. Then, the generated Neotest node
    tree is modified by mutating private attributes and merging of nodes to avoid
    duplicates. I'm personally a bit afraid of the maintenance burden of this
    feature... 🙈

!!! note "Table tests not supported"

    Right now, table tests are not supported for testify suites. This can be
    remedied at any time by extending the treesitter queries. Feel free to dig in
    and open a PR!

### `testify_operand`

Default value: `"^(s|suite)$"`

Extend this regex value to support something other than e.g. `s.Run` or
`suite.Run` for running subtests.

??? example "Custom subtest operand"

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

### `testify_import_identifier`

Default value: `"^(suite)$"`

Extend this regex value if you use a custom import identifier.

??? example "Custom import identifier"

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

### `colorize_test_output`

Default value: `true`

Enable output color for `SUCCESS`, `FAIL`, and `SKIP` tests.

### `warn_test_name_dupes`

Default value: `true`

Warn about duplicate test names within the same Go package.

### `warn_test_not_executed`

Default value: `true`

Warn if test was not executed.

### `log_level`

Default value: `"vim.log.levels.WARN"`

Neotest-golang piggybacks on the Neotest logger but writes its own file. The
default log level is `WARN` but during troubleshooting you want to increase
this. See `:h vim.log.levels` for all levels.

??? example "Increasing the log level"

    ```lua
    local config = {
        log_level = vim.log.levels.TRACE, -- set log level
    }

    require("neotest").setup({
      adapters = {
        require("neotest-golang")(config), -- Apply configuration
      },
    })
    ```

    !!! warn "Do not forget to revert"

        Don't forget to revert back to `WARN` level once you are done troubleshooting,
        as the `TRACE` level can degrade performance.

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

    ```diff
    return {
      {
        "nvim-neotest/neotest",
        dependencies = {
          "nvim-neotest/nvim-nio",
          "nvim-lua/plenary.nvim",
          "antoinemadec/FixCursorHold.nvim",
          "nvim-treesitter/nvim-treesitter",
    -      "fredrikaverpil/neotest-golang", -- Installation
    +      {
    +        "fredrikaverpil/neotest-golang", -- Installation
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
