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
      -- commit = "52fca6717ef972113ddd6ca223e30ad0abb2800c", -- BUG: https://github.com/nvim-neotest/neotest/issues/531
      branch = "fix/subprocess/load-adapters", -- FIX: this fixes the above bug for now
      dependencies = {
        "nvim-neotest/nvim-nio",
        "nvim-lua/plenary.nvim",
        "antoinemadec/FixCursorHold.nvim",
        "nvim-treesitter/nvim-treesitter",

        "MisanthropicBit/neotest-busted",
        -- "nvim-neotest/neotest-plenary",
        "nvim-neotest/neotest-vim-test",
      },
    },
    { dir = "." },
  },
})

-- Install go parser for treesitter
require("nvim-treesitter.configs").setup({
  ensure_installed = { "go" },
  auto_install = true,
  sync_install = true,
})

-- Give treesitter some time and attempt manual install
vim.cmd("sleep 100m")
pcall(function()
  require("nvim-treesitter.install").install("go")
end)

-- Copy the parser from luarocks installation to nvim-treesitter
local parser_source = vim.env.LAZY_STDPATH
  .. "/data/nvim-fredrik/lazy-rocks/neotest-golang/lib/lua/5.1/parser/go.so"
local parser_dest = vim.env.LAZY_STDPATH
  .. "/data/nvim-fredrik/lazy/nvim-treesitter/parser/go.so"
pcall(function()
  local uv = vim.uv or vim.loop
  local source_stat = uv.fs_stat(parser_source)
  if source_stat then
    local content = assert(io.open(parser_source, "rb")):read("*all")
    assert(io.open(parser_dest, "wb")):write(content)
  end
end)

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
