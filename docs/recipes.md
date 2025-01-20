---
icon: material/food
---

# Recipes

## Debugging

To debug tests, make sure you depend on
[mfussenegger/nvim-dap](https://github.com/mfussenegger/nvim-dap) and
[rcarriga/nvim-dap-ui](https://github.com/rcarriga/nvim-dap-ui).

Then you have two options:

- DAP configuration provided by
  [leoluz/nvim-dap-go](https://github.com/leoluz/nvim-dap-go) (recommended)
- Use your own custom DAP configuration (no additional dependency needed)

??? example "Adapter-provided (recommended)"

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

??? example "Use your own custom DAP configuration"

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
    +      local options = {
    +        dap_mode = "manual",
    +        dap_manual_config = {
    +          name = "Debug go tests",
    +          type = "go", -- Preconfigured DAP adapter name
    +          request = "launch",
    +          mode = "test",
    +        },
    +      }
          require("neotest").setup({
            adapters = {
    +         require("neotest-golang")(options) -- Registration
            },
          })
        end,
      },
    }
    ```

</details>

Finally, set keymaps to run Neotest commands.

!!! example "Keymap for debugging nearest test"

    ```lua
    return {
      {
        "nvim-neotest/neotest",
        -- ...
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

## Coverage

You can use
[andythigpen/nvim-coverage](https://github.com/andythigpen/nvim-coverage) to
show coverage in Neovim.

!!! example "Coverage"

    ```lua
    return {
      {
        "nvim-neotest/neotest",
        dependencies = {
          "nvim-neotest/nvim-nio",
          "nvim-lua/plenary.nvim",
          "antoinemadec/FixCursorHold.nvim",
          "nvim-treesitter/nvim-treesitter",
          {
            "fredrikaverpil/neotest-golang",
            version = "*",
            dependencies = {
              "andythigpen/nvim-coverage", -- Added dependency
            },
          },
        },
        config = function()
          local neotest_golang_opts = {  -- Specify configuration
            runner = "go",
            go_test_args = {
              "-v",
              "-race",
              "-count=1",
              "-coverprofile=" .. vim.fn.getcwd() .. "/coverage.out",
            },
          }
          require("neotest").setup({
            adapters = {
              require("neotest-golang")(neotest_golang_opts), -- Registration
            },
          })
        end,
      },
    }
    ```

## Using build tags

If you need to set build tags (like e.g. `-tags debug` or `-tags "tag1 tag2"`),
you need to provide these arguments both in the `go_test_args` and
`go_list_args` adapter options. If you want to be able to debug, you also need
to set `dap_go_opts`. Full example:

!!! example "Build tags"

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

## Pass arguments as function instead of table

Some use cases may require you to pass in dynamically generated arguments during
runtime. To cater for this, you can provide arguments as a function.

!!! example "Args passed as functions"

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

## Per-project configuration

Depending on how you have Neovim setup, you can define the neotest-golang config
on a per-project basis by placing a `.lazy.lua` with overrides in the project.
This requires the [lazy.nvim](https://github.com/folke/lazy.nvim) plugin
manager.

## Example configuration: extra everything

In the below code block, I've provided a pretty hefty configuration example,
which includes the required setup for testing and debugging along with all the
keymaps. This is a merged snapshot of my own config, which I hope you can draw
inspiration from. To view my current config, which is divided up into several
files, see:

- [plugins/neotest.lua](https://github.com/fredrikaverpil/dotfiles/blob/main/nvim-fredrik/lua/fredrik/plugins/core/neotest.lua)
- [plugins/dap.lua](https://github.com/fredrikaverpil/dotfiles/blob/main/nvim-fredrik/lua/fredrik/plugins/core/dap.lua)
- [lang/go.lua](https://github.com/fredrikaverpil/dotfiles/blob/main/nvim-fredrik/lua/fredrik/plugins/lang/go.lua)

!!! tip "Extra everything"

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
