#!/usr/bin/env -S nvim -l

-- Clean bootstrap approach for isolated test environment
-- Based on the working plenary bootstrap pattern

vim.cmd([[set runtimepath=$VIMRUNTIME]]) -- Reset to clean slate
print("Runtime path: " .. vim.inspect(vim.opt.runtimepath:get()))

vim.opt.swapfile = false
local site_dir = ".tests/busted/site"
vim.opt.packpath = { site_dir } -- Set packpath to isolated site directory

-- Clone down plugins to isolated location
local plugins = {
  ["plenary.nvim"] = { url = "https://github.com/nvim-lua/plenary.nvim" },
  ["nvim-nio"] = { url = "https://github.com/nvim-neotest/nvim-nio" },
  ["nvim-treesitter"] = {
    url = "https://github.com/nvim-treesitter/nvim-treesitter",
  },
  ["neotest"] = {
    url = "https://github.com/nvim-neotest/neotest",
    branch = "fix/subprocess/load-adapters", -- TODO: use default branch when merged
  },
  ["FixCursorHold.nvim"] = {
    url = "https://github.com/antoinemadec/FixCursorHold.nvim",
  },
  ["neotest-busted"] = {
    url = "https://github.com/MisanthropicBit/neotest-busted",
  },
  ["utf8.nvim"] = { url = "https://github.com/uga-rosa/utf8.nvim" },
}

for plugin, data in pairs(plugins) do
  local plugin_path = site_dir .. "/pack/deps/start/" .. plugin
  if vim.fn.isdirectory(plugin_path) ~= 1 then
    local clone_cmd = "git clone " .. data.url .. " " .. plugin_path
    if data.branch then
      clone_cmd = clone_cmd .. " --branch " .. data.branch
    end
    print("Cloning " .. plugin .. "...")
    os.execute(clone_cmd)
  else
    print("Plugin " .. plugin .. " already downloaded")
  end
  print("Adding to runtimepath: " .. plugin_path)
  vim.opt.runtimepath:append(plugin_path)
end

-- Add current project to runtimepath
vim.opt.runtimepath:append(".")

-- Add busted lua path for require statements with fallback paths
local busted_paths = {
  ".tests/luarocks/share/lua/5.1", -- Local installation (preferred)
  vim.fn.expand("~/.luarocks/share/lua/5.1"), -- User installation
  "/usr/local/share/lua/5.1", -- System installation
}

local busted_cpaths = {
  ".tests/luarocks/lib/lua/5.1", -- Local installation (preferred)
  vim.fn.expand("~/.luarocks/lib/lua/5.1"), -- User installation
  "/usr/local/lib/lua/5.1", -- System installation
}

-- Build package path with all potential busted locations
for _, lua_path in ipairs(busted_paths) do
  package.path = lua_path
    .. "/?.lua;"
    .. lua_path
    .. "/?/init.lua;"
    .. package.path
end

-- Build package cpath with all potential busted locations
for _, lua_cpath in ipairs(busted_cpaths) do
  package.cpath = lua_cpath .. "/?.so;" .. package.cpath
end

print("Final runtime path: " .. vim.inspect(vim.opt.runtimepath:get()))
print("Package path: " .. package.path)

-- Test busted availability immediately after setting package path
local success, busted_runner = pcall(require, "busted.runner")
if not success then
  print("Error: Could not load busted.runner module")
  print("Error details: " .. tostring(busted_runner))
  print("Tried these busted paths:")
  for _, path in ipairs(busted_paths) do
    print("  " .. path)
  end
  print("Current package.path: " .. package.path)

  -- Try alternative busted loading approaches
  print("Attempting alternative busted loading...")
  success, busted_runner = pcall(require, "busted")
  if success and busted_runner.runner then
    busted_runner = busted_runner.runner
    print("Successfully loaded busted via alternative method")
  else
    print("Failed to load busted via alternative method")
    os.exit(1)
  end
end

-- Load required modules (nvim-nio has different require path)
require("plenary")
require("nio")
require("neotest")
require("nvim-treesitter")

-- Install Go parser in isolated environment
print("Setting up TreeSitter with Go parser...")
require("nvim-treesitter.configs").setup({
  ensure_installed = { "go" },
  auto_install = true,
  sync_install = true,
})

-- Set PATH to include luarocks bin (for busted)
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

print("Busted test environment initialized successfully!")

-- Run busted internally within neovim process (key insight from lazy.nvim)
print("Running busted tests using internal busted.runner...")
print("This should make vim commands available since standalone=false")

-- Run busted with standalone=false to keep vim globals available
local ok, exit_code = pcall(busted_runner, {
  standalone = false,
})

if not ok then
  print("Busted tests failed with error: " .. tostring(exit_code))
  os.exit(1)
elseif exit_code ~= 0 and exit_code ~= nil then
  print("Busted tests failed with exit code: " .. tostring(exit_code))
  os.exit(exit_code or 1)
else
  print("All busted tests passed!")
  os.exit(0)
end
