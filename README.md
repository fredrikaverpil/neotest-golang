# neotest-golang

A Neotest adapter for running Go tests.

<img width="1528" alt="neotest-golang" src="https://github.com/fredrikaverpil/neotest-golang/assets/994357/4f6e1fa6-2274-42e6-ba94-9a205061e5de">

## ⭐️ Features

- Supports all [Neotest usage](https://github.com/nvim-neotest/neotest#usage).
- Integrates with [nvim-dap-go](https://github.com/leoluz/nvim-dap-go) for
  debugging of tests using delve.
- Inline diagnostics.
- Works great with
  [andythigpen/nvim-coverage](https://github.com/andythigpen/nvim-coverage) for
  displaying coverage in the sign column (per-Go package, or per-test basis).
- Monorepo support (detect, run and debug tests in sub-projects).
- Supports table tests (relies on treesitter AST detection).
- Supports nested test functions.

## 🚧 Work in progress

This Neotest adapter is under heavy development and I'm dogfooding myself with
this project on a daily basis, as full-time Go developer.

My next focus areas:

- [ ] Refactoring, polish and the addition of tests.
- [ ] Documentation around expanding new syntax support for table tests via AST
      parsing.
- [ ] Add debug logging:
      [neotest#422](https://github.com/nvim-neotest/neotest/discussions/422)
- [ ] Investigate ways to speed up test execution when executing tests in a
      file.

## 🏓 Background

I've been using Neovim and Neotest with
[neotest-go](https://github.com/nvim-neotest/neotest-go) but I have stumbled
upon many problems which seem difficult to solve in the neotest-go codebase.

I have full respect for the time and efforts put in by the developer(s) of
neotest-go. I do not aim in any way to diminish their needs or efforts.

However, I would like to see if, by building a Go adapter for Neotest from
scratch, if I can mitigate the issues I have found with neotest-go.

### Neotest-go issues mitigated in neotest-golang

- Test Output in JSON, making it difficult to read:
  [neotest-go#52](https://github.com/nvim-neotest/neotest-go/issues/52)
- "Run nearest" runs all tests:
  [neotest-go#83](https://github.com/nvim-neotest/neotest-go/issues/83)
- Running test suite doesn't work:
  [neotest-go#89](https://github.com/nvim-neotest/neotest-go/issues/89)
- Diagnostics for table tests on the line of failure:
  [neotest-go#75](https://github.com/nvim-neotest/neotest-go/issues/75)
- Support for Nested Subtests:
  [neotest-go#74](https://github.com/nvim-neotest/neotest-go/issues/74)
- DAP support:
  [neotest-go#12](https://github.com/nvim-neotest/neotest-go/issues/12)

### Upstream/dependency issues found during development

- Test output is printed undesirably:
  [neotest#391](https://github.com/nvim-neotest/neotest/issues/391). This is
  currently mitigated in neotest-golang by reading the neotest-written test
  output file on disk, parsing it and then erasing its contents.

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
    "-parallel=1",
    "-p=2",
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
