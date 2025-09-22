local M = {}

--- Initialize the test environment.
--- This file will run once before attempting to run PlenaryBustedDirectory, so to set up requirements.
--- Also see minimal_init.lua which runs before each test file.
function M.init()
  vim.cmd([[set runtimepath=$VIMRUNTIME]]) -- reset, otherwise it contains all of $PATH

  local site_dir = ".tests/all/site"
  print("Runtime path: " .. vim.inspect(vim.opt.runtimepath:get()))
  print("Package path: " .. package.path)
  print("Site directory: " .. site_dir)

  vim.opt.runtimepath:append(".") -- add project root to runtime path so we can require our adapter
  vim.opt.runtimepath:append(site_dir) -- add site directory to runtime path so neovim can find parsers
  vim.opt.packpath = { site_dir } -- add site directory to packpath so plugins can be found
  vim.opt.swapfile = false

  -- Clone down plugins, add to runtimepath
  local plugins = {
    ["plenary.nvim"] = { url = "https://github.com/nvim-lua/plenary.nvim" },
    ["nvim-nio"] = { url = "https://github.com/nvim-neotest/nvim-nio" },
    ["nvim-treesitter"] = {
      url = "https://github.com/nvim-treesitter/nvim-treesitter",
      branch = "master",
    },
    neotest = {
      url = "https://github.com/nvim-neotest/neotest",
    },
  }
  for plugin, data in pairs(plugins) do
    local plugin_path = site_dir .. "/pack/deps/start/" .. plugin
    if vim.fn.isdirectory(plugin_path) ~= 1 then
      print("Cloning " .. plugin .. "...")
      local clone_cmd = "git clone " .. data.url
      if data.branch then
        clone_cmd = clone_cmd .. " --branch " .. data.branch
      end
      clone_cmd = clone_cmd .. " " .. plugin_path
      os.execute(clone_cmd)
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

    -- HACK: Update nvim-nio timeout value if this is the nvim-nio plugin
    local test_timeout = 500000 -- timeout in milliseconds
    if plugin == "nvim-nio" then
      local tests_file_path = plugin_path .. "/lua/nio/tests.lua"
      if vim.fn.filereadable(tests_file_path) == 1 then
        print("Updating timeout in nvim-nio tests.lua...")
        local content = io.open(tests_file_path, "r"):read("*all")
        -- Replace the hardcoded 2000 timeout with our variable
        content = content:gsub("timeout or 2000", "timeout or " .. test_timeout)
        local file = io.open(tests_file_path, "w")
        file:write(content)
        file:close()
        print("Updated nvim-nio timeout to " .. test_timeout .. "ms")
      end
    end
  end

  -- Check availability
  require("plenary")
  require("nio")
  require("nvim-treesitter")
  require("neotest")

  -- Ensure parser directory exists with proper permissions
  local parser_dir = site_dir .. "/parser"
  if vim.fn.isdirectory(parser_dir) ~= 1 then
    vim.fn.mkdir(parser_dir, "p")
    print("Created parser directory: " .. parser_dir)
  end

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
        runner = "gotestsum",
        go_test_args = { "-v", "-race", "-count=1" },
        colorize_test_output = false,
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
