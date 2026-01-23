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
    if plugin == "nvim-nio" then
      local tests_file_path = plugin_path .. "/lua/nio/tests.lua"
      if vim.fn.filereadable(tests_file_path) == 1 then
        print("Updating timeout in nvim-nio tests.lua...")
        local content = io.open(tests_file_path, "r"):read("*all")
        -- Replace the hardcoded 2000 timeout with our variable
        content = content:gsub("timeout or 2000", "timeout or " .. TEST_TIMEOUT)
        local file = io.open(tests_file_path, "w")
        file:write(content)
        file:close()
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

  -- Configuare nvim-treesitter to use the site directory for parsers
  print("Configuring nvim-treesitter install directory...")
  ---@type TSConfig
  local treesitter_opts = { install_dir = site_dir }
  require("nvim-treesitter.config").setup(treesitter_opts)

  -- Install Go parser if not already installed
  local parser_path = site_dir .. "/parser/go.so"
  local parser_installed = vim.fn.filereadable(parser_path) == 1

  if not parser_installed then
    print("Go parser not found, installing...")

    -- Debug: Check if C compiler is available
    local cc = vim.fn.exepath("cc")
    local gcc = vim.fn.exepath("gcc")
    local clang = vim.fn.exepath("clang")
    print("  C compiler check:")
    print("    cc: " .. (cc ~= "" and cc or "NOT FOUND"))
    print("    gcc: " .. (gcc ~= "" and gcc or "NOT FOUND"))
    print("    clang: " .. (clang ~= "" and clang or "NOT FOUND"))

    -- Debug: Show relevant environment
    local path = vim.fn.getenv("PATH")
    print("  PATH (first 500 chars): " .. string.sub(path or "", 1, 500))

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

    print("Waiting for parser compilation...")
    print("  Expected parser path: " .. parser_path)
    print("  Parser directory: " .. site_dir .. "/parser")
    print("  stdpath('data'): " .. vim.fn.stdpath("data"))
    print("  runtimepath: " .. table.concat(vim.opt.runtimepath:get(), ", "):sub(1, 300))

    while vim.fn.filereadable(parser_path) == 0 and waited < max_wait_seconds do
      -- Use vim.wait() to properly yield to the event loop so async jobs can complete
      vim.wait(poll_interval_ms, function()
        return vim.fn.filereadable(parser_path) == 1
      end, 50) -- check every 50ms within the wait period
      waited = waited + (poll_interval_ms / 1000)
      -- Show progress every 10 seconds
      if waited % 10 < (poll_interval_ms / 1000) then
        print(string.format("  Still waiting... (%ds)", waited))
        -- Debug: list parser directory contents
        local parser_dir = site_dir .. "/parser"
        if vim.fn.isdirectory(parser_dir) == 1 then
          local files = vim.fn.readdir(parser_dir)
          if #files > 0 then
            print("  Parser dir contents: " .. vim.inspect(files))
          else
            print("  Parser dir is empty")
          end
        else
          print("  Parser dir does not exist")
        end
        -- Debug: check nvim-treesitter install status
        local ok, install = pcall(require, "nvim-treesitter.install")
        if ok and install.is_installed then
          print("  nvim-treesitter says go installed: " .. tostring(install.is_installed("go")))
        end

        -- Debug: search for go.so in common locations
        -- Also check pocket's neovim installation path
        local nvim_exe = vim.v.progpath or vim.fn.exepath("nvim")
        local nvim_base = vim.fn.fnamemodify(nvim_exe, ":h:h") -- go up from bin/ to root
        local search_paths = {
          site_dir .. "/parser",
          vim.fn.stdpath("data") .. "/site/parser",
          vim.fn.stdpath("data") .. "/lazy/nvim-treesitter/parser",
          vim.fn.stdpath("cache") .. "/nvim-treesitter/parser",
          nvim_base .. "/lib/nvim/parser",
          nvim_base .. "/share/nvim/runtime/parser",
          ".pocket/tools/neovim",
        }
        print("  nvim executable: " .. nvim_exe)
        print("  nvim base dir: " .. nvim_base)
        print("  Searching for go.so in:")
        for _, sp in ipairs(search_paths) do
          local go_so = sp .. "/go.so"
          local exists = vim.fn.filereadable(go_so) == 1
          print("    " .. sp .. ": " .. (exists and "FOUND" or "not found"))
        end

        -- Debug: check nvim-treesitter config
        local ts_ok, ts_config = pcall(require, "nvim-treesitter.config")
        if ts_ok then
          local install_dir = ts_config.get_install_dir and ts_config.get_install_dir()
          print("  nvim-treesitter install_dir: " .. tostring(install_dir))
        end

        -- Debug: check for any files in install_dir (temp files, etc)
        local install_base = site_dir
        if vim.fn.isdirectory(install_base) == 1 then
          local result = vim.fn.system("find " .. install_base .. " -name '*.so' -o -name '*.o' -o -name 'go*' 2>/dev/null | head -20")
          if result and result ~= "" then
            print("  Files matching *.so, *.o, go* in " .. install_base .. ":")
            print(result)
          end
        end

        -- Debug: check nvim-treesitter install module for any status
        local inst_ok, ts_install = pcall(require, "nvim-treesitter.install")
        if inst_ok then
          -- Check if there's an active installation
          local running = ts_install.running_installs and ts_install.running_installs()
          if running then
            print("  Running installs: " .. vim.inspect(running))
          end
        end

        -- Debug: check nvim messages for errors
        local messages = vim.fn.execute("messages")
        if messages and (messages:find("error") or messages:find("Error") or messages:find("fail")) then
          print("  Recent nvim messages (may contain errors):")
          -- Print last 500 chars of messages
          print(messages:sub(-500))
        end
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
