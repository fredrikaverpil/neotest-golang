local M = {}

local function normalize_path(path)
  return path:gsub("\\", "/")
end

function M.init()
  vim.cmd([[set runtimepath=$VIMRUNTIME]])
  vim.opt.runtimepath:append(".")
  vim.opt.swapfile = false

  -- vim.opt.packpath = {
  --   ".tests/all/site",
  -- }
  --
  -- vim.cmd([[
  --     packadd plenary.nvim
  --     packadd neotest
  --     packadd nvim-nio
  --     packadd nvim-treesitter
  --   ]])

  -- Set packpath with explicit paths
  local test_dir = normalize_path(vim.fn.getcwd() .. "/.tests/all/site")
  vim.opt.packpath = { test_dir }

  -- Load plugins with explicit paths
  local plugins = {
    "plenary.nvim",
    "neotest",
    "nvim-nio",
    "nvim-treesitter",
  }

  -- Ensure the required Neovim plugins are installed/cloned
  if vim.fn.has("win32") == 1 then
    os.execute("bash -c 'tests/install.sh'")
  else
    os.execute("tests/install.sh")
  end

  print("PLUGINS CLONED")

  for _, plugin in ipairs(plugins) do
    local plugin_path =
      normalize_path(test_dir .. "/pack/deps/start/" .. plugin)
    if vim.fn.isdirectory(plugin_path) ~= 1 then
      -- create path
      print("Creating path: " .. plugin_path)
      vim.fn.mkdir(plugin_path, "p")
    end
    vim.opt.runtimepath:append(plugin_path)
  end

  -- Load plenary explicitly
  local plenary_path =
    normalize_path(test_dir .. "/pack/deps/start/plenary.nvim/lua")
  package.path = package.path
    .. ";"
    .. plenary_path
    .. "/?.lua;"
    .. plenary_path
    .. "/?/init.lua"

  -- Source plenary's plugin files
  vim.cmd([[runtime plugin/plenary.vim]])

  if vim.fn.exists(":PlenaryBustedDirectory") == 0 then
    vim.notify(
      "minimal_init.lua: Failed to find PlenaryBustedDirectory command. Aborting!",
      vim.log.levels.ERROR
    )
    print("Current runtimepath: " .. vim.opt.runtimepath:get())

    vim.cmd("q!")
  end

  print("RTPATH UPDATED")

  require("nvim-treesitter.configs").setup({
    ensure_installed = { "go", "lua" }, -- This will install go and lua parsers
    auto_install = true,
    sync_install = true,
  })

  print("DONE")
end

M.init()
