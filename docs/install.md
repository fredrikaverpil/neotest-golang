---
icon: material/progress-check
---

# Installation

!!! warning "Minimum Neovim version"

    Neovim v0.10.0 or above is required.

## 💤 Lazy.nvim

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
      local neotest_golang_opts = {}  -- Specify custom configuration
      require("neotest").setup({
        adapters = {
          require("neotest-golang")(neotest_golang_opts), -- Registration
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
ultimately it is up to you what you want.

!!! tip "Gotestsum"

    Although neotest-golang is designed to run tests with `go test -json`, there are
    a plethora of issues with reading JSON from stdout. It is recommended that you
    configure neotest-golang to use
    [`gotestsum`](https://github.com/gotestyourself/gotestsum) as test runner, for
    maximal stability, as it writes JSON to file instead. Head over to the
    [configuration docs](/config/#runner) for more details.

    ```diff
    return {
      {
        "nvim-neotest/neotest",
        dependencies = {
          "nvim-neotest/nvim-nio",
          "nvim-lua/plenary.nvim",
          "antoinemadec/FixCursorHold.nvim",
          "nvim-treesitter/nvim-treesitter",
    -     { "fredrikaverpil/neotest-golang", version = "*" }, -- Installation
    +     {
    +       "fredrikaverpil/neotest-golang",
    +       version = "*",
    +       build = "go run gotest.tools/gotestsum@latest"
    +     },
        },
        config = function()
    -     local neotest_golang_opts = {}  -- Specify custom configuration
    +     local neotest_golang_opts = {  -- Specify custom configuration
    +       runner = "gotestsum",
    +     }
          require("neotest").setup({
            adapters = {
              require("neotest-golang")(neotest_golang_opts), -- Registration
            },
          })
        end,
      },
    }
    ```

    Also, see the [Lazy versioning spec](https://lazy.folke.io/spec/versioning) for more
    details on configuring plugins for lazy.nvim.

## 🌒 Rocks.nvim

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

!!! note "Luarocks"

    Please note that [leoluz/nvim-dap-go](https://github.com/leoluz/nvim-dap-go)
    (required for DAP) is not on luarocks as of writing this.

## ❄️ Nix & Home manager

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
