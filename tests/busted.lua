#!/usr/bin/env -S nvim -l
vim.env.LAZY_STDPATH = ".tests"
load(
  vim.fn.system(
    "curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"
  )
)()

-- local cwd = vim.loop.cwd()
--
-- vim.opt.rtp:append(cwd)
-- vim.opt.rtp:append(cwd .. "/.tests/lazy.nvim")

require("lazy.minit").busted({
  spec = {

    "nvim-lua/plenary.nvim",
    "nvim-neotest/nvim-nio",
    "nvim-neotest/neotest",
    {
      "nvim-treesitter/nvim-treesitter",
      config = function()
        local configs = require("nvim-treesitter.configs")

        configs.setup({
          ensure_installed = { "lua", "go" },
          sync_install = true,
        })
      end,
    },
  },
})
