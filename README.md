# neotest-golang

A neotest adapter for running go tests.

## 🚧 Pre-release

This neotest adapter is under heavy development and considered beta.

My next focus areas:

- [ ] Refactoring, polish and tests.
  - [ ] Make use of `pcall` to handle potential errors gracefully.
- [ ] Set up CI for linting, testing, require changes via PR.
- [ ] Versioning and releases via release-please.
- [ ] Ability to debug test from sub-project.
- [ ] Get rid of the `gotestsum` dependency in favour for native tooling
      (blocked by
      [neotest#391](https://github.com/nvim-neotest/neotest/issues/391)).
- [ ] Investigate ways to speed up test execution when running dir/file.
- [ ] Documentation around expanding new syntax support for table tests via AST
      parsing.
- [ ] Add debug logging, set up bug report form.

## 🏓 Background

I've been using Neovim and neotest with
[neotest-go](https://github.com/nvim-neotest/neotest-go) but I have stumbled
upon many problems which seems difficult to solve in the neotest-go codebase.

I have full respect for the time and efforts put in by the developer(s) of
neotest-go. I do not aim in any way to diminish their needs or efforts.

However, I would like to see if, by building a Go adapter for neotest from
scractch, whether it will be possible to mitigate the issues I have found with
neotest-go.

## ⛑️ Neotest-go issues mitigated in neotest-golang

- Test Output in JSON, making it difficult to read:
  [neotest-go#52](https://github.com/nvim-neotest/neotest-go/issues/52)
- "Run nearest" runs all tests:
  [neotest-go#83](https://github.com/nvim-neotest/neotest-go/issues/83)
- Running test suite doesn't work:
  [neotest-go#89](https://github.com/nvim-neotest/neotest-go/issues/89)

## 🪲 Upstream bugs found

- Test output is printed undesirably:
  [neotest#391](https://github.com/nvim-neotest/neotest/issues/391). This is
  currently mitigated in neotest-golang by using `gotestsum`. Long-term, it
  would be great to be able to use the intended behavior of neotest and just run
  `go test`.
- Arithmetic error which prevents errors from being shown as inline diagnostics:
  [neotest#396](https://github.com/nvim-neotest/neotest/pull/396) (PR filed).

## 🥸 Installation and configuration

You need to have [`gotestsum`](https://github.com/gotestyourself/gotestsum) on
your `$PATH`:

```bash
go install gotest.tools/gotestsum@latest
```

### 💤 Lazy.nvim

```lua
return {
  "nvim-neotest/neotest",
  dependencies = {
    "fredrikaverpil/neotest-golang", -- Installation
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "antoinemadec/FixCursorHold.nvim",
  },
  config = function()
    require("neotest").setup({
      adapters = {
        require("neotest-golang"), -- Registration
      }
    })
  end
}
```

### ⚙️ Configuration

| Argument | Default value                                  | Description                         |
| -------- | ---------------------------------------------- | ----------------------------------- |
| `args`   | `{ "-v", "-race", "-count=1", "timeout=60s" }` | Arguments to pass into `gotestsum`. |

Example:

```lua
return {
  "nvim-neotest/neotest",
  dependencies = {
    "fredrikaverpil/neotest-golang",
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
    "antoinemadec/FixCursorHold.nvim",
  },
  config = function()
    local config = { -- Specify configuration
      args = {
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
      }
    })
  end
}
```

<details>
<summary>Full example</summary>

```lua
return {
  -- Neotest setup
  {
    "nvim-neotest/neotest",
    event = "VeryLazy",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter",

      "nvim-neotest/neotest-plenary",
      "nvim-neotest/neotest-vim-test",

      "nvim-neotest/nvim-nio",

      {
        "fredrikaverpil/neotest-golang",
        branch = "main",
        buil = "go install gotest.tools/gotestsum@latest",
      },
    },
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}
      opts.adapters["neotest-golang"] = {
        args = {
          "-v",
          "-race",
          "-count=1",
          "-timeout=60s",
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
you to begin in the discussions in case the change is not trivial.
