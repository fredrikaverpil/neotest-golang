---
icon: material/progress-check
---

# Installation

!!! warning "Requirements"

    - **Neovim v0.10.0+** is required
    - **Go tree-sitter parser** is required (see setup below)
    - **gotestsum** is recommended for best experience (optional)

## 💤 Lazy.nvim

```lua
return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      { "nvim-treesitter/nvim-treesitter", branch = "main" }, -- Optional
      {
        "fredrikaverpil/neotest-golang",
        version = "*",  -- Optional, but recommended
        build = function()
          vim.system({"go", "install", "gotest.tools/gotestsum@latest"}):wait() -- Optional, but recommended
          vim.cmd([[:TSUpdate go]])  -- Optional
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

!!! note "Recommended: Track releases"

    For increased stability and fewer updates, set `version = "*"` to track official releases.

    - `version = "*"` → Latest stable release (recommended)
    - `version = false` → Latest from main branch (cutting edge)
    - Specific versions → Not recommended (you'll miss important fixes)

!!! danger "Required: Go tree-sitter parser"

    **What's required:** The [Go tree-sitter parser](https://github.com/tree-sitter/tree-sitter-go)
    is required for neotest-golang to detect and parse Go tests.

    **Installation options:**

    1. **Via nvim-treesitter** (recommended):
       ```vim
       :TSInstall go
       :TSUpdate go
       ```

    2. **Alternative methods:** You can install the parser via system package managers, Nix, or other means.

    **When nvim-treesitter is required:**
    - **Always required** for [testify suite features](config.md#testify_enabled)
    - Optional for basic test discovery (parser can be installed via alternative methods)

    **Important version requirement:**
    ⚠️ **BREAKING**: neotest-golang v2+ requires the Go parser from nvim-treesitter's
    [`main` branch](https://github.com/nvim-treesitter/nvim-treesitter/tree/main).
    The frozen `master` branch is not supported.

    **Parser stability notice:**
    The tree-sitter-go project doesn't use semantic versioning and may introduce
    breaking changes without notice. Neotest-golang tracks nvim-treesitter's curated
    parser versions to provide stability, but parser updates can still potentially break
    functionality. The community actively maintains compatibility with parser updates,
    ensuring broad ecosystem support.

    If you experience issues after updating, consider rolling back the parser version.
    You can check the exact parser version being used in nvim-treesitter's
    [`parsers.lua`](https://github.com/nvim-treesitter/nvim-treesitter/blob/main/lua/nvim-treesitter/parsers.lua).

!!! tip "Recommended: Use gotestsum runner"

    **Why gotestsum?** Although neotest-golang works with `go test -json`, there are
    many issues with reading JSON from stdout (corruption, truncation, ANSI codes).
    For examples, see [common problems](trouble.md#common_problems).

    **Solution:** Use [`gotestsum`](https://github.com/gotestyourself/gotestsum)
    as your test runner for maximum stability. It writes clean JSON to file instead
    of stdout, eliminating parsing issues entirely.

    The example above shows the recommended configuration with gotestsum.
    See [configuration docs](config.md/#runner) for more details.

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
