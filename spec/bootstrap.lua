local M = {}

-- Shared constants (duplicated in minimal_init.lua for simplicity)
local SITE_DIR = ".tests/all/site"
local TEST_TIMEOUT = 500000

-- Shared plugin configuration (duplicated in minimal_init.lua for simplicity)
local PLUGINS = {
  ["plenary.nvim"] = { url = "https://github.com/nvim-lua/plenary.nvim" },
  ["nvim-nio"] = { url = "https://github.com/nvim-neotest/nvim-nio" },
  ["nvim-treesitter"] = {
    url = "https://github.com/nvim-treesitter/nvim-treesitter",
    branch = "main",
  },
  neotest = {
    url = "https://github.com/nvim-neotest/neotest",
  },
}

--- Initialize the test environment.
--- This file will run once before attempting to run PlenaryBustedDirectory, so to set up requirements.
--- Also see minimal_init.lua which runs before each test file.
function M.init()
  vim.cmd([[set runtimepath=$VIMRUNTIME]]) -- reset, otherwise it contains all of $PATH

  local site_dir = SITE_DIR
  print("Runtime path: " .. vim.inspect(vim.opt.runtimepath:get()))
  print("Package path: " .. package.path)
  print("Site directory: " .. site_dir)

  vim.opt.runtimepath:append(".") -- add project root to runtime path so we can require our adapter
  vim.opt.runtimepath:append(site_dir) -- add site directory to runtime path so neovim can find parsers
  vim.opt.packpath = { site_dir } -- add site directory to packpath so plugins can be found
  vim.opt.swapfile = false

  -- Clone down plugins, add to runtimepath
  for plugin, data in pairs(PLUGINS) do
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
        local handle =
          io.popen("cd " .. plugin_path .. " && git rev-parse HEAD")
        local current_hash = handle:read("*a"):gsub("%s+", "")
        handle:close()
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

    -- HACK: Update nvim-nio timeout value if this is the nvim-nio plugin.
    -- nvim-nio has a hardcoded 2000ms timeout that's too short for CI.
    if plugin == "nvim-nio" then
      local tests_file_path = plugin_path .. "/lua/nio/tests.lua"
      if vim.fn.filereadable(tests_file_path) == 1 then
        print("Updating timeout in nvim-nio tests.lua...")
        local read_handle = io.open(tests_file_path, "r")
        local content = read_handle:read("*all")
        read_handle:close()
        -- Replace the hardcoded 2000 timeout with our variable
        content = content:gsub("timeout or 2000", "timeout or " .. TEST_TIMEOUT)
        local write_handle = io.open(tests_file_path, "w")
        write_handle:write(content)
        write_handle:close()
        print("Updated nvim-nio timeout to " .. TEST_TIMEOUT .. "ms")
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

  -- Configure nvim-treesitter to use the site directory for parsers
  print("Configuring nvim-treesitter install directory...")
  ---@type TSConfig
  local treesitter_opts = { install_dir = site_dir }
  require("nvim-treesitter.config").setup(treesitter_opts)

  -- Verify tree-sitter CLI is available (required for parser compilation)
  local tree_sitter = vim.fn.exepath("tree-sitter")
  if tree_sitter ~= "" then
    print("tree-sitter CLI: " .. tree_sitter)
  else
    print(
      "WARNING: tree-sitter CLI not found in PATH - parser compilation may fail"
    )
  end

  -- Install Go parser if not already installed
  -- Note: nvim-treesitter uses .so extension on all platforms (including Windows)
  local parser_path = site_dir .. "/parser/go.so"
  local parser_installed = vim.fn.filereadable(parser_path) == 1

  if not parser_installed then
    print("Go parser not found, installing...")
    print("  Expected path: " .. parser_path)

    -- Start async installation
    local success, result = pcall(function()
      require("nvim-treesitter.install").install({ "go" })
    end)

    if not success then
      error("Failed to start parser installation: " .. tostring(result))
    end

    -- Poll for parser file existence (wait() doesn't block in headless mode)
    local max_wait_seconds = 300 -- 5 minutes
    local poll_interval_ms = 500
    local waited = 0

    while vim.fn.filereadable(parser_path) == 0 and waited < max_wait_seconds do
      vim.wait(poll_interval_ms, function()
        return vim.fn.filereadable(parser_path) == 1
      end, 50)
      waited = waited + (poll_interval_ms / 1000)
      if waited % 30 < (poll_interval_ms / 1000) then
        print(
          string.format("  Waiting for parser compilation... (%ds)", waited)
        )
      end
    end

    if vim.fn.filereadable(parser_path) == 0 then
      error(
        "Parser installation timed out after "
          .. max_wait_seconds
          .. " seconds. "
          .. "Parser file not found at: "
          .. parser_path
      )
    end

    print("Go parser installed successfully at: " .. parser_path)
  else
    print("Go parser already installed at: " .. parser_path)
  end

  -- Do not initialize Neotest here to avoid affecting unit tests
  -- The integration tests will set up neotest as needed
  print("Neotest adapter available for testing...")

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
