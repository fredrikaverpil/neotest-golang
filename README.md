# neotest-golang

Reliable Neotest adapter for running Go tests in Neovim.

<img width="1528" alt="neotest-golang" src="https://github.com/fredrikaverpil/neotest-golang/assets/994357/4f6e1fa6-2274-42e6-ba94-9a205061e5de">

## ⭐️ Features

- Supports all [Neotest usage](https://github.com/nvim-neotest/neotest#usage).
- Supports table tests and nested test functions (based on AST/tree-sitter
  detection).
- DAP support with [nvim-dap-go](https://github.com/leoluz/nvim-dap-go)
  integration for debugging of tests using
  [delve](https://github.com/go-delve/delve).
- Monorepo support (detect, run and debug tests in sub-projects).
- Inline diagnostics.
- Custom `go test` argument support.
- Works great with
  [andythigpen/nvim-coverage](https://github.com/andythigpen/nvim-coverage) for
  displaying coverage in the sign column (per-Go package, or per-test basis).

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
| DAP support                                             | [neotest-go#12](https://github.com/nvim-neotest/neotest-go/issues/12) |
| Test Output in JSON, making it difficult to read        | [neotest-go#52](https://github.com/nvim-neotest/neotest-go/issues/52) |
| Support for Nested Subtests                             | [neotest-go#74](https://github.com/nvim-neotest/neotest-go/issues/74) |
| Diagnostics for table tests on the line of failure      | [neotest-go#75](https://github.com/nvim-neotest/neotest-go/issues/75) |
| "Run nearest" runs all tests                            | [neotest-go#83](https://github.com/nvim-neotest/neotest-go/issues/83) |
| Table tests not recognized when defined inside for-loop | [neotest-go#86](https://github.com/nvim-neotest/neotest-go/issues/86) |
| Running test suite doesn't work                         | [neotest-go#89](https://github.com/nvim-neotest/neotest-go/issues/89) |

</details>

## 🥸 Installation

### 💤 Lazy.nvim

```lua
return {
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
          require("neotest-golang"), -- Registration
        },
      })
    end,
  },
}
```

## ⚙️ Configuration

| Argument                 | Default value                   | Description                                                                               |
| ------------------------ | ------------------------------- | ----------------------------------------------------------------------------------------- |
| `go_test_args`           | `{ "-v", "-race", "-count=1" }` | Arguments to pass into `go test`.                                                         |
| `dap_go_enabled`         | `false`                         | Leverage [leoluz/nvim-dap-go](https://github.com/leoluz/nvim-dap-go) for debugging tests. |
| `dap_go_opts`            | `{}`                            | Options to pass into `require("dap-go").setup()`.                                         |
| `warn_test_name_dupes`   | `true`                          | Warn about duplicate test names within the same Go package.                               |
| `warn_test_not_executed` | `true`                          | Warn if test was not executed.                                                            |

### Example configuration: custom `go test` arguments

```lua
local config = { -- Specify configuration
  go_test_args = {
    "-v",
    "-race",
    "-count=1",
    "-timeout=60s",
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

See `go help test` for possible arguments.

### Example configuration: debugging

To debug tests, make sure you depend on
[mfussenegger/nvim-dap](https://github.com/mfussenegger/nvim-dap),
[rcarriga/nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui) and
[leoluz/nvim-dap-go](https://github.com/leoluz/nvim-dap-go).

Then set `dap_go_enabled` to `true`:

```lua
local config = { dap_go_enabled = true } -- Specify configuration
require("neotest").setup({
  adapters = {
    require("neotest-golang")(config), -- Apply configuration
  },
})
```

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

### Example configuration: extra everything

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
          "-count=1",
          "-timeout=60s",
          "-coverprofile=" .. vim.fn.getcwd() .. "/coverage.out",
        },
        dap_go_enabled = true,
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
    },
  },

  -- DAP setup
  {
    "mfussenegger/nvim-dap",
    event = "VeryLazy",
    dependencies = {
      {
        "rcarriga/nvim-dap-ui",
        dependencies = {
          "nvim-neotest/nvim-nio",
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
      {
        "leoluz/nvim-dap-go",
        opts = {},
      },
    },
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
}
```

</details>

## ⛑️ Tips & troubleshooting

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
        concurrent = false,
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

You can set the optional neotest-go `go_test_args` to control the number of test
binaries and number of tests to run in parallel using the `-p` and `-parallel`
flags, respectively. Execute `go help test` and `go help testflag` for more
information on this and perhaps have a look at
[my own configuration](https://github.com/fredrikaverpil/dotfiles/blob/main/nvim-fredrik/lua/lang/go.lua)
for inspiration.

## 🙏 PRs are welcome

Improvement suggestion PRs to this repo are very much welcome, and I encourage
you to begin in the
[discussions](https://github.com/fredrikaverpil/neotest-golang/discussions) in
case the change is not trivial.

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
query and play around. You can paste in queries from `ast.lua` in the editor, to
see how the query behaves and highlights parts of your Go test file.
