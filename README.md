# neotest-golang

Reliable Neotest adapter for running Go tests in Neovim.

![neotest-golang](https://github.com/fredrikaverpil/neotest-golang/assets/994357/afb6e936-b355-4d7b-ab73-65c21ee66ae7)

## ⭐️ Features

- Supports all [Neotest usage](https://github.com/nvim-neotest/neotest#usage).
- Supports table tests and nested test functions (based on treesitter AST
  parsing).
- DAP support. Either with
  [leoluz/nvim-dap-go](https://github.com/leoluz/nvim-dap-go) integration or
  custom configuration for debugging of tests using
  [delve](https://github.com/go-delve/delve).
- Monorepo support (detect, run and debug tests in sub-projects).
- Inline diagnostics.
- Custom `go test` argument support.
- Works great with
  [andythigpen/nvim-coverage](https://github.com/andythigpen/nvim-coverage) for
  displaying coverage in the sign column.
- Supports [testify](https://github.com/stretchr/testify) suites.

<details>
<summary>Why a second Neotest adapter for Go? 🤔</summary>

While using [neotest-go](https://github.com/nvim-neotest/neotest-go) I stumbled
upon many problems which seemed difficult to solve in that codebase.

I have full respect for the time and efforts put in by the developer(s) of
neotest-go. I do not aim in any way to diminish their needs or efforts. However,
I wanted to see if I could fix these issues by diving into the 🕳️🐇 of Neotest
and building my own adapter. Below is a list of neotest-go issues which are not
present in neotest-golang (this project):

| Neotest-go issue                                        | URL                                                                   |
| ------------------------------------------------------- | --------------------------------------------------------------------- |
| Support for Testify framework                           | [neotest-go#6](https://github.com/nvim-neotest/neotest-go/issues/6)   |
| DAP support                                             | [neotest-go#12](https://github.com/nvim-neotest/neotest-go/issues/12) |
| Test Output in JSON, making it difficult to read        | [neotest-go#52](https://github.com/nvim-neotest/neotest-go/issues/52) |
| Support for Nested Subtests                             | [neotest-go#74](https://github.com/nvim-neotest/neotest-go/issues/74) |
| Diagnostics for table tests on the line of failure      | [neotest-go#75](https://github.com/nvim-neotest/neotest-go/issues/75) |
| "Run nearest" runs all tests                            | [neotest-go#83](https://github.com/nvim-neotest/neotest-go/issues/83) |
| Table tests not recognized when defined inside for-loop | [neotest-go#86](https://github.com/nvim-neotest/neotest-go/issues/86) |
| Running test suite doesn't work                         | [neotest-go#89](https://github.com/nvim-neotest/neotest-go/issues/89) |

And here, a comparison in number of GitHub stars between the projects:

[![Star History Chart](https://api.star-history.com/svg?repos=fredrikaverpil/neotest-golang,nvim-neotest/neotest-go&type=Date)](https://star-history.com/#fredrikaverpil/neotest-golang&nvim-neotest/neotest-go&Date)

</details>

## 🥸 Installation

> [!NOTE]
>
> Requires Neovim 0.10.0 and above.

<details>
<summary>💤 Lazy.nvim</summary>

```lua
return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      { "fredrikaverpil/neotest-golang", version = "*" }, -- Installation
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-golang"), -- Registration
        },
      })
    end,
  },
}
```

For increased stability and less updating noise, I recommend that you track
official releases by setting `version = "*"`. By omitting this option (or
setting `version = false`), you will get the latest and greatest directly from
the main branch.

I do not recommend pinning to a specific version or to a major version. But
ultimately it is up to you what you want :smile:.

See the [Lazy versioning spec](https://lazy.folke.io/spec/versioning) for more
details.

</details>

<details>
<summary>🌒 Rocks.nvim</summary>

The adapter is available via
[luarocks package](https://luarocks.org/modules/fredrikaverpil/neotest-golang):

```vim
:Rocks install neotest-golang
```

[rocks.nvim](https://github.com/nvim-neorocks/rocks.nvim) will automatically
install dependencies if they are not already installed. You will need to call
neotest's `setup` function to register this adapter. If you use
[rocks-config.nvim](https://github.com/nvim-neorocks/rocks-config.nvim),
consider setting up neotest and its adapters in a
[plugin bundle](https://github.com/nvim-neorocks/rocks-config.nvim?tab=readme-ov-file#plugin-bundles).

> [!NOTE]
>
> Please note that [leoluz/nvim-dap-go](https://github.com/leoluz/nvim-dap-go)
> (required for DAP) is not on luarocks as of writing this.

</details>

<details>
<summary>❄️ Nix & Home manager</summary>

```nix
{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [];
  programs = {
    neovim = {
      plugins = [
        # neotest and dependencies
        pkgs.vimPlugins.neotest
        pkgs.vimPlugins.nvim-nio
        pkgs.vimPlugins.plenary-nvim
        pkgs.vimPlugins.FixCursorHold-nvim
        pkgs.vimPlugins.nvim-treesitter
        (pkgs.vimPlugins.nvim-treesitter.withPlugins (plugins: [plugins.go]))
        pkgs.vimPlugins.neotest-golang

        ## debugging
        pkgs.vimPlugins.nvim-dap
        pkgs.vimPlugins.nvim-dap-ui
        pkgs.vimPlugins.nvim-nio
        pkgs.vimPlugins.nvim-dap-virtual-text
        pkgs.vimPlugins.nvim-dap-go
      ];
      enable = true;
      extraConfig = ''
        lua << EOF
        require("neotest").setup({
          adapters = {
            require("neotest-golang")
          },
        })
        EOF
      '';
    };
  };
}
```

</details>

## ⚙️ Configuration

| Argument                 | Default value                     | Description                                                                                                                                                                                                                                                                                                                          |
| ------------------------ | --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `runner`                 | `go`                              | Defines the test runner. Valid values: `go` or `gotestsum`.                                                                                                                                                                                                                                                                          |
| `go_test_args`           | `{ "-v", "-race", "-count=1" }`   | Arguments to pass into `go test`. Notes: [`-tags` usage](https://github.com/fredrikaverpil/neotest-golang#using-build-tags), [pass args as function](https://github.com/fredrikaverpil/neotest-golang#pass-arguments-as-function-instead-of-table).                                                                                  |
| `gotestsum_args`         | `{ "--format=standard-verbose" }` | Arguments to pass into `gotestsum`. Notes: [`-tags` usage](https://github.com/fredrikaverpil/neotest-golang#using-build-tags), [pass args as function](https://github.com/fredrikaverpil/neotest-golang#pass-arguments-as-function-instead-of-table). Will only be used if `runner = "gotestsum"`. The `go_test_args` still applies. |
| `go_list_args`           | `{}`                              | Arguments to pass into `go list`. Note: [`-tags` usage](https://github.com/fredrikaverpil/neotest-golang#using-build-tags), [pass args as function](https://github.com/fredrikaverpil/neotest-golang#pass-arguments-as-function-instead-of-table).                                                                                   |
| `dap_go_opts`            | `{}`                              | Options to pass into `require("dap-go").setup()`. Note: [`-tags` usage](https://github.com/fredrikaverpil/neotest-golang#using-build-tags), [pass args as function](https://github.com/fredrikaverpil/neotest-golang#pass-arguments-as-function-instead-of-table).                                                                   |
| `testify_enabled`        | `false`                           | Enable support for [testify](https://github.com/stretchr/testify) suites. See [here](https://github.com/fredrikaverpil/neotest-golang#testify-suites) for more info.                                                                                                                                                                 |
| `colorize_test_output`   | `true`                            | Enable output color for `SUCCESS`, `FAIL`, and `SKIP` tests.                                                                                                                                                                                                                                                                         |
| `warn_test_name_dupes`   | `true`                            | Warn about duplicate test names within the same Go package.                                                                                                                                                                                                                                                                          |
| `warn_test_not_executed` | `true`                            | Warn if test was not executed.                                                                                                                                                                                                                                                                                                       |
| `log_level`              | `vim.log.levels.WARN`             | Log level.                                                                                                                                                                                                                                                                                                                           |

> [!NOTE]
>
> The `-race` flag (in `go_test_args`) requires CGO to be enabled
> (`CGO_ENABLED=1` is the default) and a C compiler (such as GCC) to be
> installed. However, since Go 1.20, this is not a requirement on macOS. I have
> included the `-race` argument as default, as it provides good production
> defaults. See [this issue](https://github.com/golang/go/issues/9918) for more
> details.

> [!IMPORTANT]
>
> The `gotestsum` runner is recommended for Windows users or if you are using
> Ubuntu snaps. You can read more below on `gotestsum`.

### Example configuration: custom `go test` arguments

```lua
local config = { -- Specify configuration
  go_test_args = {
    "-v",
    "-race",
    "-count=1",
    "-coverprofile=" .. vim.fn.getcwd() .. "/coverage.out",
  },
}
require("neotest").setup({
  adapters = {
    require("neotest-golang")(config), -- Apply configuration
  },
})
```

Note that the example above writes a coverage file. You can use
[andythigpen/nvim-coverage](https://github.com/andythigpen/nvim-coverage) to
show the coverage in Neovim.

See `go help test`, `go help testflag`, `go help build` for possible arguments.

### Example configuration: debugging

To debug tests, make sure you depend on
[mfussenegger/nvim-dap](https://github.com/mfussenegger/nvim-dap) and
[rcarriga/nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui). Then you have
two options:

<details>
<summary>
    Adapter-provided DAP configuration,
    leveraging leoluz/nvim-dap-go (recommended).
</summary>

```diff
return {
+  {
+    "rcarriga/nvim-dap-ui",
+    dependencies = {
+      "nvim-neotest/nvim-nio",
+      "mfussenegger/nvim-dap",
+    },
+  },
+
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
+          "leoluz/nvim-dap-go",
+        },
+      },
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-golang"), -- Registration
        },
      })
    end,
  },
}
```

</details>

<details>
<summary>Use your own custom DAP configuration (no additional dependency needed).</summary>

```diff
return {
+  {
+    "rcarriga/nvim-dap-ui",
+    dependencies = {
+      "nvim-neotest/nvim-nio",
+      "mfussenegger/nvim-dap",
+    },
+  },
+
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",
      "fredrikaverpil/neotest-golang", -- Installation
    },
    config = function()
      require("neotest").setup({
        adapters = {
+         require("neotest-golang") { -- Registration
+           dap_mode = "manual",
+           dap_manual_config = {
+               name = "Debug go tests",
+               type = "go", -- Preconfigured DAP adapter name
+               request = "launch",
+               mode = "test",
+           }
+         },
        },
      })
    end,
  },
}
```

</details><br>

Finally, set a keymap, like:

```lua
return {
  {
    "nvim-neotest/neotest",
    ...
    keys = {
      {
        "<leader>td",
        function()
          require("neotest").run.run({ suite = false, strategy = "dap" })
        end,
        desc = "Debug nearest test",
      },
    },
  },
}
```

For a more verbose example, see the "extra everything" example config.

### Using `gotestsum` as test runner

To improve reliability, you can choose to set
[`gotestsum`](https://github.com/gotestyourself/gotestsum) as the test runner.
This tool allows the adapter to write test command output directly to a JSON
file, without going through stdout.

Using `gotestsum` offers the following benefits:

- When you "attach" to a running test, you'll see clean `go test` output instead
  of having to navigate through difficult-to-read JSON.
- On certain platforms (such as Windows) or terminals, there's a risk of ANSI
  codes or other characters being seemingly randomly inserted into the JSON test
  output. This can corrupt the data and cause problems with test output JSON
  decoding. Enabling `gotestsum` eliminates these issues, as the test output is
  then written directly to file.

`gotestsum` calls `go test` behind the scenes, so your `go_test_args`
configuration remains valid and will still apply.

> [!NOTE]
>
> See
> [this issue comment](https://github.com/fredrikaverpil/neotest-golang/issues/193#issuecomment-2362845806)
> for more details on reported issues on Windows and Ubuntu snaps.

#### Configure neotest-golang to use `gotestsum` as test runner

Make the `gotestsum` command availalbe via
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

### Example configuration: extra everything

In the below code block, I've provided a pretty hefty configuration example,
which includes the required setup for testing and debugging along with all the
keymaps. This is a merged snapshot of my own config, which I hope you can draw
inspiration from. To view my current config, which is divided up into several
files, see:

- [plugins/neotest.lua](https://github.com/fredrikaverpil/dotfiles/blob/main/nvim-fredrik/lua/plugins/neotest.lua)
- [plugins/dap.lua](https://github.com/fredrikaverpil/dotfiles/blob/main/nvim-fredrik/lua/plugins/dap.lua)
- [lang/go.lua](https://github.com/fredrikaverpil/dotfiles/blob/main/nvim-fredrik/lua/lang/go.lua)

<details>
<summary>Click to expand</summary>

```lua
return {

  -- Neotest setup
  {
    "nvim-neotest/neotest",
    event = "VeryLazy",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",

      "nvim-neotest/neotest-plenary",
      "nvim-neotest/neotest-vim-test",

      {
        "fredrikaverpil/neotest-golang",
        dependencies = {
          {
            "leoluz/nvim-dap-go",
            opts = {},
          },
        },
        branch = "main",
      },
    },
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}
      opts.adapters["neotest-golang"] = {
        go_test_args = {
          "-v",
          "-race",
          "-coverprofile=" .. vim.fn.getcwd() .. "/coverage.out",
        },
      }
    end,
    config = function(_, opts)
      if opts.adapters then
        local adapters = {}
        for name, config in pairs(opts.adapters or {}) do
          if type(name) == "number" then
            if type(config) == "string" then
              config = require(config)
            end
            adapters[#adapters + 1] = config
          elseif config ~= false then
            local adapter = require(name)
            if type(config) == "table" and not vim.tbl_isempty(config) then
              local meta = getmetatable(adapter)
              if adapter.setup then
                adapter.setup(config)
              elseif adapter.adapter then
                adapter.adapter(config)
                adapter = adapter.adapter
              elseif meta and meta.__call then
                adapter(config)
              else
                error("Adapter " .. name .. " does not support setup")
              end
            end
            adapters[#adapters + 1] = adapter
          end
        end
        opts.adapters = adapters
      end

      require("neotest").setup(opts)
    end,
    keys = {
      { "<leader>ta", function() require("neotest").run.attach() end, desc = "[t]est [a]ttach" },
      { "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "[t]est run [f]ile" },
      { "<leader>tA", function() require("neotest").run.run(vim.uv.cwd()) end, desc = "[t]est [A]ll files" },
      { "<leader>tS", function() require("neotest").run.run({ suite = true }) end, desc = "[t]est [S]uite" },
      { "<leader>tn", function() require("neotest").run.run() end, desc = "[t]est [n]earest" },
      { "<leader>tl", function() require("neotest").run.run_last() end, desc = "[t]est [l]ast" },
      { "<leader>ts", function() require("neotest").summary.toggle() end, desc = "[t]est [s]ummary" },
      { "<leader>to", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "[t]est [o]utput" },
      { "<leader>tO", function() require("neotest").output_panel.toggle() end, desc = "[t]est [O]utput panel" },
      { "<leader>tt", function() require("neotest").run.stop() end, desc = "[t]est [t]erminate" },
      { "<leader>td", function() require("neotest").run.run({ suite = false, strategy = "dap" }) end, desc = "Debug nearest test" },
      { "<leader>tD", function() require("neotest").run.run({ vim.fn.expand("%"), strategy = "dap" }) end, desc = "Debug current file" },
    },
  },

  -- DAP setup
  {
    "mfussenegger/nvim-dap",
    event = "VeryLazy",
    keys = {
      {"<leader>db", function() require("dap").toggle_breakpoint() end, desc = "toggle [d]ebug [b]reakpoint" },
      {"<leader>dB", function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, desc = "[d]ebug [B]reakpoint"},
      {"<leader>dc", function() require("dap").continue() end, desc = "[d]ebug [c]ontinue (start here)" },
      {"<leader>dC", function() require("dap").run_to_cursor() end, desc = "[d]ebug [C]ursor" },
      {"<leader>dg", function() require("dap").goto_() end, desc = "[d]ebug [g]o to line" },
      {"<leader>do", function() require("dap").step_over() end, desc = "[d]ebug step [o]ver" },
      {"<leader>dO", function() require("dap").step_out() end, desc = "[d]ebug step [O]ut" },
      {"<leader>di", function() require("dap").step_into() end, desc = "[d]ebug [i]nto" },
      {"<leader>dj", function() require("dap").down() end, desc = "[d]ebug [j]ump down" },
      {"<leader>dk", function() require("dap").up() end, desc = "[d]ebug [k]ump up" },
      {"<leader>dl", function() require("dap").run_last() end, desc = "[d]ebug [l]ast" },
      {"<leader>dp", function() require("dap").pause() end, desc = "[d]ebug [p]ause" },
      {"<leader>dr", function() require("dap").repl.toggle() end, desc = "[d]ebug [r]epl" },
      {"<leader>dR", function() require("dap").clear_breakpoints() end, desc = "[d]ebug [R]emove breakpoints" },
      {"<leader>ds", function() require("dap").session() end, desc ="[d]ebug [s]ession" },
      {"<leader>dt", function() require("dap").terminate() end, desc = "[d]ebug [t]erminate" },
      {"<leader>dw", function() require("dap.ui.widgets").hover() end, desc = "[d]ebug [w]idgets" },
    },
  },

  -- DAP UI setup
  {
    "rcarriga/nvim-dap-ui",
    event = "VeryLazy",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "mfussenegger/nvim-dap",
    },
    opts = {},
    config = function(_, opts)
      -- setup dap config by VsCode launch.json file
      -- require("dap.ext.vscode").load_launchjs()
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup(opts)
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open({})
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close({})
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close({})
      end
    end,
    keys = {
      { "<leader>du", function() require("dapui").toggle({}) end, desc = "[d]ap [u]i" },
      { "<leader>de", function() require("dapui").eval() end, desc = "[d]ap [e]val" },
    },
  },
  {
    "theHamsta/nvim-dap-virtual-text",
    opts = {},
  },
}
```

</details>

## ⛑️ Tips & troubleshooting

### Issues with setting up or using the adapter

> [!TIP]
>
> You can run `:checkhealth neotest-golang` to review common issues. If you need
> configuring neotest-golang help, please open a discussion
> [here](https://github.com/fredrikaverpil/neotest-golang/discussions/new?category=configuration).

You can also enable logging to further inspect what's going on under the hood.
Neotest-golang piggybacks on the Neotest logger but writes its own file. The
default log level is `WARN` but during troubleshooting you want to increase
this:

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

The neotest-golang logs can be opened using this convenient vim command:

```vim
:exe 'edit' stdpath('log').'/neotest-golang.log'
```

This usually corresponds to something like
`~/.local/state/nvim/neotest-golang.log`.

> [!WARNING]
>
> Don't forget to revert back to `WARN` level once you are done troubleshooting,
> as the `TRACE` level can degrade performance.

### Neotest is slowing down Neovim

Neotest, out of the box with default settings, can appear very slow in large
projects (here, I'm referring to
[this kind of large](https://github.com/kubernetes/kubernetes)). There are a few
things you can do to speed up the Neotest appearance and experience in such
cases, by tweaking the Neotest settings.

You can for example limit the AST-parsing (to detect tests) to the currently
opened file, which in my opinion makes Neotest a joy to work with, even in
ginormous projects. Second, you can tweak the concurrency settings, again for
AST-parsing but also for concurrent test execution. Here is a simplistic example
for [lazy.nvim](https://github.com/folke/lazy.nvim) to show what I mean:

```lua
return {
  {
    "nvim-neotest/neotest",
    opts = {
      -- See all config options with :h neotest.Config
      discovery = {
        -- Drastically improve performance in ginormous projects by
        -- only AST-parsing the currently opened buffer.
        enabled = false,
        -- Number of workers to parse files concurrently.
        -- A value of 0 automatically assigns number based on CPU.
        -- Set to 1 if experiencing lag.
        concurrent = 1,
      },
      running = {
        -- Run tests concurrently when an adapter provides multiple commands to run.
        concurrent = true,
      },
      summary = {
        -- Enable/disable animation of icons.
        animated = false,
      },
    },
  },
}
```

See `:h neotest.Config` for more information.

[Here](https://github.com/fredrikaverpil/dotfiles/blob/main/nvim-fredrik/lua/plugins/neotest.lua)
is my personal Neotest configuration, for inspiration. Please note that I am
configuring Go and the neotest-golang adapter in a separate file
[here](https://github.com/fredrikaverpil/dotfiles/blob/main/nvim-fredrik/lua/lang/go.lua).

### Go test execution and parallelism

You can set the optional `go_test_args` to control the number of test binaries
and number of tests to run in parallel using the `-p` and `-parallel` flags,
respectively. Execute `go help test`, `go help testflag`, `go help build` for
more information on this. There's also an excellent article written by
[@roblaszczak](https://github.com/roblaszczak) posted
[here](https://threedots.tech/post/go-test-parallelism/) that touches on this
subject further.

### Testify suites

> [!WARNING]
>
> This feature comes with some caveats and nuances, which is why it is not
> enabled by default. I advise you to only enable this if you need it.

There are some real shenaningans going on behind the scenes to make this work.
😅 First, an in-memory lookup of "receiver type-to-suite test function" will be
created of all Go test files in your project. Then, the generated Neotest node
tree is modified by mutating private attributes and merging of nodes to avoid
duplicates. I'm personally a bit afraid of the maintenance burden of this
feature... 🙈

> [!NOTE]
>
> Right now, nested tests and table tests are not supported. All of this can be
> remedied at any time by extending the treesitter queries. Feel free to dig in
> and open a PR!

### Using build tags

If you need to set build tags (like e.g. `-tags debug` or `-tags "tag1 tag2"`),
you need to provide these arguments both in the `go_test_args` and
`go_list_args` adapter options. If you want to be able to debug, you also need
to set `dap_go_opts`. Full example:

```lua
return {
  {
    "nvim-neotest/neotest",
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-golang")({
            go_test_args = { "-count=1", "-tags=integration" },
            go_list_args = { "-tags=integration" },
            dap_go_opts = {
              delve = {
                build_flags = { "-tags=integration" },
              },
            },
          }),
        },
      })
    end,
  },
}
```

> [!TIP]
>
> Depending on how you have Neovim setup, you can define this on a per-project
> basis by placing a `.lazy.lua` with overrides in the project. This requires
> the [lazy.nvim](https://github.com/folke/lazy.nvim) plugin manager.

### Pass arguments as function instead of table

Some use cases may require you to pass in dynamically generated arguments during
runtime. To cater for this, you can provide arguments as a function.

```lua
return {
  {
    "nvim-neotest/neotest",
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-golang")({
            go_test_args = function()
              -- provide custom logic here..
              return { "-count=1", "-tags=integration" }
            end,
            go_list_args = function()
              -- provide custom logic here..
              return { "-tags=integration" }
            end,
            dap_go_opts = function()
              -- provide custom logic here..
              return {
                delve = {
                  build_flags = { "-tags=integration" },
                },
              }
            end,
            },
          }),
        },
      })
    end,
  },
}
```

## 🙏 PRs are welcome

Improvement suggestion PRs to this repo are very much welcome, and I encourage
you to begin by reading the below paragraph on the adapter design and engage in
the [discussions](https://github.com/fredrikaverpil/neotest-golang/discussions)
in case the change is not trivial.

You can run tests, formatting and linting locally with `make all`. Install
dependencies with `make install`. Have a look at the [Makefile](Makefile) for
more details. You can also use the neotest-plenary and neotest-golang adapters
to run the tests of this repo within Neovim.

### AST and tree-sitter

To figure out new tree-sitter queries (for detecting tests), the following
commands are available in Neovim to aid you:

- `:Inspect` to show the highlight groups under the cursor.
- `:InspectTree` to show the parsed syntax tree (formerly known as
  "TSPlayground").
- `:EditQuery` to open the Live Query Editor (Nvim 0.10+).

For example, open up a Go test file and then execute `:InspectTree`. A new
window will appear which shows what the tree-sitter query syntax representation
looks like for the Go test file.

Again, from the Go test file, execute `:EditQuery` to open up the query editor
in a separate window. In the editor, you can now start creating your syntax
query and play around. You can paste in queries from
[`query.lua`](https://github.com/fredrikaverpil/neotest-golang/blob/main/lua/neotest-golang/query.lua)
in the editor, to see how the query behaves and highlights parts of your Go test
file.

## General design of the adapter

### Treesitter queries detect tests

Neotest leverages treesitter AST-parsing of source code to detect tests. This
adapter supplies queries so to figure out what is considered a test.

From the result of these queries, a Neotest "position" tree is built (can be
visualized through the "Neotest summary"). Each position in the tree represents
either a `dir`, `file` or `test` type. Neotest also has a notion of a
`namespace` position type, but this is ignored by default by this adapter (but
leveraged to supply testify support).

### Generating valid `go test` commands

The `dir`, `file` and `test` tree position types cannot be directly translated
over to Go so to produce a valid `go test` command. Go primarily cares about a
Go package's import path, test name regexp filters and the current working
directory.

For example, these are all valid `go test` command:

```bash
# run all tests, recursing sub-packages, in the current working directory.
go test ./...

# run all tests in a given package 'x', by specifying the full import path
go test github.com/fredrikaverpil/neotest-golang/x

# run all tests in a given package 'x', recursing sub-packages
go test github.com/fredrikaverpil/neotest-golang/x/...

# run _some_ tests in a given package, based on a regexp filter
go test github.com/fredrikaverpil/neotest-golang -run "^(^TestFoo$|^TestBar$)$"
```

> [!NOTE]
>
> All the above commands must be run somewhere beneath the location of the
> `go.mod` file specifying the _module_ name, which in this example is
> `github.com/fredrikaverpil/neotest-golang`.

I figured out that by executing `go list -json ./...` in the `go.mod` root
location, the output provides valuable information about test files/folders and
their corresponding Go package's import path. This data is key to being able to
take the Neotest/treesitter position type and generate a valid `go test` command
for it. In essence, this approach is what makes neotest-golang so robust.

### Output processing

Neotest captures the stdout from the test execution command and writes it to
disk as a temporary file. The adapter is responsible for reading the file(s) and
reporting back status and output to the Neotest tree (and specifically the
position in the tree which was executed). It is therefore crucial for outputting
structured data, which in this case is done with `go test -json`.

One challenge here is that Go build errors are not part of the strucutured JSON
output (although captured in the stdout) and needs to be looked for in other
ways.

Another challenge is to properly populate statuses and errors into the
corresponding Neotest tree position. This becomes increasingly difficult when
you consider running tests in a recursive manner (e.g. `go test -json ./...`).

Errors are recorded and populated, per position type, along with its
corresponding buffer's line number. Neotest can then show the errors inline as
diagnostics.

I've taken an approach with this adapter where I record test outcome for each
Neotest position type and populate it onto each of them, when applicable.

On some systems and terminals, there are great issues with the `go test` output.
I've therefore made it possible to make the adapter rely on output saved
directly to disk without going through stdout, by leveraging `gotestsum`.
