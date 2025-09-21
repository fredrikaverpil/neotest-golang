local M = {}

--- Initialize before running each test.
--- Also see bootstrap.lua which runs once before all tests.
function M.init()
  vim.cmd([[set runtimepath=$VIMRUNTIME]]) -- reset, otherwise it contains all of $PATH

  local site_dir = ".tests/all/site"

  vim.opt.runtimepath:append(".") -- add project root to runtime path so we can require our adapter
  vim.opt.runtimepath:append(site_dir) -- add site directory to runtime path so neovim can find parsers
  vim.opt.packpath = { site_dir } -- add site directory to packpath so plugins can be found
  vim.opt.swapfile = false

  -- Add all the plugins to runtime path (they should already be downloaded by bootstrap)
  local plugins = { "plenary.nvim", "nvim-nio", "nvim-treesitter", "neotest" }
  for _, plugin in ipairs(plugins) do
    local plugin_path = site_dir .. "/pack/deps/start/" .. plugin
    vim.opt.runtimepath:append(plugin_path)
  end
end

M.init()
