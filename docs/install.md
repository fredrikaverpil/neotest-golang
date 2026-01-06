______________________________________________________________________

## icon: material/progress-check

# Installation

!!! warning "Requirements"
    - **Neovim v0.10.0+**
    - **Go parser** from
      [tree-sitter-go](https://github.com/tree-sitter/tree-sitter-go)
    - [Gotestsum](https://github.com/gotestyourself/gotestsum) (optional, but
      heavily recommended for best experience)

## 💤 Lazy.nvim

```lua
return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      {
        "nvim-treesitter/nvim-treesitter", -- Optional, but recommended
        branch = "main",  -- NOTE; not the master branch!
        build = function()
          vim.cmd(":TSUpdate go")
        end,
      },
      {
        "fredrikaverpil/neotest-golang",
        version = "*",  -- Optional, but recommended; track releases
        build = function()
          vim.system({"go", "install", "gotest.tools/gotestsum@latest"}):wait() -- Optional, but recommended
        end,
      },
    },
    config = function()
      local config = {
        runner = "gotestsum", -- Optional, but recommended
      }
      require("neotest").setup({
        adapters = {
          require("neotest-golang")(config),
        },
      })
    end,
  },
}
```

_See the [Lazy versioning spec](https://lazy.folke.io/spec/versioning) for more
details._

!!! danger "Required: Go tree-sitter parser"
    - The [tree-sitter-go parser](https://github.com/tree-sitter/tree-sitter-go) is
      required for neotest-golang to detect and parse Go tests.
      - Installation options:
        1. Via nvim-treesitter (recommended):
           ```vim
           :TSInstall go
           :TSUpdate go
           ```
        1. Alternative methods: You can install the parser via system package
           managers, Nix, or other means.
    - Nvim-treesitter is optional (parser can be installed via alternative methods)
      but _required_ for [testify suite features](config.md#testify_enabled).
    - The tree-sitter-go project unfortunately doesn't use semantic versioning and
      may introduce breaking changes without notice. Therefore, neotest-golang
      tracks nvim-treesitter's curated parser versions to provide stability.
      - ⚠️ neotest-golang v2+ expects the Go parser version from nvim-treesitter's
        [`main` branch](https://github.com/nvim-treesitter/nvim-treesitter/tree/main).
        The frozen `master` branch is no longer supported.
      - If you experience issues after updating nvim-treesitter (and subsequently,
        the Go parser), consider rolling back nvim-treesitter and re-installing the
        Go parser associated with that nvim-treesitter release. You can check the
        exact parser version being used in nvim-treesitter's
        [`parsers.lua`](https://github.com/nvim-treesitter/nvim-treesitter/blob/main/lua/nvim-treesitter/parsers.lua).

!!! tip "Recommended: Use gotestsum runner"
    Although neotest-golang works with `go test -json`, there are many issues with
    reading JSON from stdout (corruption, truncation, ANSI codes). For examples, see
    [common problems](trouble.md#common-problems).

    It is recommended to use
    [`gotestsum`](https://github.com/gotestyourself/gotestsum) as your test runner
    for maximum stability. It writes JSON to file instead of stdout, eliminating all
    such stdout issues entirely.

    The installation example above shows the recommended configuration with
    gotestsum. See [configuration docs](config.md/#runner) for more details.

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
