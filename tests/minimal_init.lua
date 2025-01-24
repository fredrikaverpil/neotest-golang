local M = {}

local function normalize_path(path)
  return path:gsub("\\", "/")
end

local function git_clone()
  -- Ensure the required Neovim plugins are installed/cloned
  if vim.fn.has("win32") == 1 then
    os.execute("bash -c 'tests/install.sh'")
  else
    os.execute("tests/install.sh")
  end
end

function M.init()
  vim.cmd([[set runtimepath=$VIMRUNTIME]])
  vim.opt.runtimepath:append(".")
  vim.opt.swapfile = false

  git_clone()

  local test_dir = normalize_path(vim.fn.getcwd() .. "/.tests/all/site")
  vim.opt.packpath = { test_dir }

  -- Load plugins with explicit paths
  local plugins = {
    "plenary.nvim",
    "neotest",
    "nvim-nio",
    "nvim-treesitter",
  }

  for _, plugin in ipairs(plugins) do
    local plugin_path =
      normalize_path(test_dir .. "/pack/deps/start/" .. plugin)
    if vim.fn.isdirectory(plugin_path) ~= 1 then
      vim.notify(
        "minimal_init.lua: Failed to find plugin directory: " .. plugin_path,
        vim.log.levels.ERROR
      )
      vim.cmd("q!")
    end
    vim.opt.runtimepath:append(plugin_path)
  end

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

  -- Install treesitter parsers
  require("nvim-treesitter.configs").setup({
    ensure_installed = { "go", "lua" },
    auto_install = true,
    sync_install = true,
  })
end

M.init()
