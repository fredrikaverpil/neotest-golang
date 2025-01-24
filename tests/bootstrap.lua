local M = {}

local function normalize_path(path)
  return path:gsub("\\", "/")
end

function M.init()
  vim.cmd([[set runtimepath=$VIMRUNTIME]]) -- reset, otherwise it contains all of $PATH
  print("Runtime path: " .. vim.inspect(vim.opt.runtimepath:get()))
  -- vim.opt.runtimepath:append(".") -- add project root to runtime path
  vim.opt.swapfile = false

  local site_dir = normalize_path(vim.fn.getcwd() .. "/.tests/all/site")
  vim.opt.packpath = { site_dir } -- set packpath to the site directory

  local plugins = {
    ["plenary.nvim"] = { url = "https://github.com/nvim-lua/plenary.nvim" },
    ["nvim-nio"] = { url = "https://github.com/nvim-neotest/nvim-nio" },
    ["nvim-treesitter"] = {
      url = "https://github.com/nvim-treesitter/nvim-treesitter",
    },
    neotest = { url = "https://github.com/nvim-neotest/neotest" },
  }

  for plugin, data in pairs(plugins) do
    local plugin_path =
      normalize_path(site_dir .. "/pack/deps/start/" .. plugin)
    if vim.fn.isdirectory(plugin_path) ~= 1 then
      os.execute("git clone " .. data.url .. " " .. plugin_path)
    else
      print("Plugin " .. plugin .. " already downloaded")
    end
    print("Adding to runtimepath: " .. plugin_path)
    vim.opt.runtimepath:append(plugin_path)
  end

  print("Runtime path: " .. vim.inspect(vim.opt.runtimepath:get()))
  print("Package path: " .. package.path)

  -- test availability
  require("plenary")
  require("neotest")
  require("nvim-treesitter")

  -- Installed go parser, if not already installed
  require("nvim-treesitter.configs").setup({
    ensure_installed = { "go" },
    auto_install = true,
    sync_install = true,
  })

  -- Check if PlenaryBustedDirectory command is available
  vim.cmd([[runtime plugin/plenary.vim]])
  if vim.fn.exists(":PlenaryBustedDirectory") == 0 then
    vim.notify(
      "minimal_init.lua: Failed to find PlenaryBustedDirectory command. Aborting!",
      vim.log.levels.ERROR
    )
    vim.cmd("q!")
  end
end

M.init()
