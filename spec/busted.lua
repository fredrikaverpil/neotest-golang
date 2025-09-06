#!/usr/bin/env -S nvim -l

vim.env.LAZY_STDPATH = ".tests"
load(
  vim.fn.system(
    "curl -s https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua"
  )
)()

-- Setup lazy.nvim
require("lazy.minit").busted({
  spec = {
    {
      "nvim-neotest/neotest",
      lazy = true,
      branch = "fix/subprocess/load-adapters", -- TODO: use default branch when merged
      dependencies = {
        "nvim-neotest/nvim-nio",
        "nvim-lua/plenary.nvim",
        "antoinemadec/FixCursorHold.nvim",
        "nvim-treesitter/nvim-treesitter",

        "MisanthropicBit/neotest-busted",
      },
    },
    { dir = "." },
  },
})

-- Set PATH to include luarocks bin
vim.env.PATH = vim.env.HOME .. "/.luarocks/bin:" .. vim.env.PATH

-- Initialize Neotest with both golang and busted adapters
local busted_adapter = require("neotest-busted")
local golang_adapter = require("neotest-golang")

require("neotest").setup({
  adapters = {
    -- Busted adapter for running our spec/ tests
    busted_adapter({
      -- Minimal configuration for auto-detection
      local_luarocks_only = false,
    }),
    -- Golang adapter for testing Go code
    golang_adapter({
      -- Configure for test environment
      runner = "go",
      go_test_args = { "-v", "-race", "-count=1" },
      colorize_test_output = false,
      warn_test_results_missing = false,
    }),
  },
  -- Use integrated strategy for real execution
  default_strategy = "integrated",
  -- Enable discovery for our test files
  discovery = {
    enabled = true,
  },
  -- Disable logging during tests to avoid noise
  log_level = vim.log.levels.WARN,
})
