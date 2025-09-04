local M = {}

--- Initialize the test environment.
--- Thie file will run once before attempting to run PlenaryBustedDirectory.
function M.init()
  vim.cmd([[set runtimepath=$VIMRUNTIME]]) -- reset, otherwise it contains all of $PATH
  print("Runtime path: " .. vim.inspect(vim.opt.runtimepath:get()))
  -- vim.opt.runtimepath:append(".") -- add project root to runtime path
  vim.opt.swapfile = false
  local site_dir = ".tests/all/site"
  vim.opt.packpath = { site_dir } -- set packpath to the site directory

  -- Clone down plugins, add to runtimepath
  local plugins = {
    ["plenary.nvim"] = { url = "https://github.com/nvim-lua/plenary.nvim" },
    ["nvim-nio"] = { url = "https://github.com/nvim-neotest/nvim-nio" },
    ["nvim-treesitter"] = {
      url = "https://github.com/nvim-treesitter/nvim-treesitter",
    },
    neotest = {
      url = "https://github.com/nvim-neotest/neotest",
      hash = "cd1bccbe80772c70732b43f1b95addab2083067a",
    },
  }
  for plugin, data in pairs(plugins) do
    local plugin_path = site_dir .. "/pack/deps/start/" .. plugin
    if vim.fn.isdirectory(plugin_path) ~= 1 then
      print("Cloning " .. plugin .. "...")
      os.execute("git clone " .. data.url .. " " .. plugin_path)
      if data.hash then
        print("Checking out hash " .. data.hash .. " for " .. plugin)
        os.execute("cd " .. plugin_path .. " && git checkout " .. data.hash)
      end
    else
      print("Plugin " .. plugin .. " already downloaded")
      if data.hash then
        -- Verify we're on the right hash
        local current_hash =
          io.popen("cd " .. plugin_path .. " && git rev-parse HEAD")
            :read("*a")
            :gsub("%s+", "")
        if current_hash ~= data.hash then
          print("Updating " .. plugin .. " to hash " .. data.hash)
          os.execute(
            "cd "
              .. plugin_path
              .. " && git fetch && git checkout "
              .. data.hash
          )
        else
          print("Plugin " .. plugin .. " already on correct hash")
        end
      end
    end
    print("Adding to runtimepath: " .. plugin_path)
    vim.opt.runtimepath:append(plugin_path)
  end

  print("Runtime path: " .. vim.inspect(vim.opt.runtimepath:get()))
  print("Package path: " .. package.path)

  -- Add project root to runtime path so we can require our adapter
  vim.opt.runtimepath:append(".")

  -- Check availability
  require("plenary")
  require("neotest")
  require("nvim-treesitter")

  -- Install go parser, if not already installed
  require("nvim-treesitter.configs").setup({
    ensure_installed = { "go" },
    auto_install = true,
    sync_install = true,
  })

  -- Initialize Neotest with our golang adapter
  print("Initializing Neotest with golang adapter...")
  local adapter = require("neotest-golang")
  require("neotest").setup({
    adapters = {
      adapter({
        -- Configure for test environment
        runner = "go",
        go_test_args = { "-v", "-race", "-count=1" },
        colorize_test_output = false,
        warn_test_results_missing = false,
        -- Don't set env here as it might cause issues
      }),
    },
    -- Use integrated strategy for real execution
    default_strategy = "integrated",
    -- Enable discovery for our test Go files
    discovery = {
      enabled = true,
    },
    -- Disable logging during tests to avoid noise
    log_level = vim.log.levels.WARN,
  })
  print("Neotest initialized successfully!")

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
