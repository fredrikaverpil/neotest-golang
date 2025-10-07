local M = {}

-- Shared constants (duplicated from bootstrap.lua for simplicity)
local SITE_DIR = ".tests/all/site"

--- Initialize before running each test.
--- Also see bootstrap.lua which runs once before all tests.
function M.init()
  vim.cmd([[set runtimepath=$VIMRUNTIME]]) -- reset, otherwise it contains all of $PATH

  local site_dir = SITE_DIR

  vim.opt.runtimepath:append(".") -- add project root to runtime path so we can require our adapter
  vim.opt.runtimepath:append(site_dir) -- add site directory to runtime path so neovim can find parsers
  vim.opt.packpath = { site_dir } -- add site directory to packpath so plugins can be found
  vim.opt.swapfile = false

  -- Add all the plugins to runtime path (they should already be downloaded by bootstrap)
  local plugins = { "plenary.nvim", "nvim-nio", "nvim-treesitter", "neotest" }
  for _, plugin in ipairs(plugins) do
    local plugin_path = site_dir .. "/pack/deps/start/" .. plugin
    if vim.fn.isdirectory(plugin_path) == 0 then
      error(
        "Plugin "
          .. plugin
          .. " not found at "
          .. plugin_path
          .. ". "
          .. "Please run 'task test-clean && task test' first to initialize the test environment."
      )
    end
    vim.opt.runtimepath:append(plugin_path)
  end

  -- Check that the Go parser exists
  local parser_path = site_dir .. "/parser/go.so"
  if vim.fn.filereadable(parser_path) == 0 then
    error(
      "Go treesitter parser not found at "
        .. parser_path
        .. ". "
        .. "Please run 'task test-clean && task test' first to initialize the test environment."
    )
  end

  -- Load plenary plugin
  vim.cmd([[runtime plugin/plenary.vim]])

  -- Load and require dependencies
  require("plenary")
  require("nio")
  require("nvim-treesitter")
  require("neotest")

  -- Configure nvim-treesitter to use the site directory for parsers
  ---@type TSConfig
  local treesitter_opts = {
    install_dir = site_dir,
    parser_install_dir = site_dir .. "/parser",
  }
  require("nvim-treesitter.config").setup(treesitter_opts)

  -- Ensure treesitter is properly initialized
  local ts_configs = require("nvim-treesitter.configs")
  ts_configs.setup({
    parser_install_dir = site_dir .. "/parser",
    ensure_installed = {},
    highlight = { enable = false }, -- Disable highlighting to avoid issues
    incremental_selection = { enable = false },
    textobjects = { enable = false },
  })

  -- Force reload treesitter parsers to ensure Go parser is recognized
  local success, ts_parsers = pcall(require, "nvim-treesitter.parsers")
  if success and ts_parsers then
    -- Force a refresh of available parsers
    pcall(function()
      ts_parsers._parsers = nil
      ts_parsers.available_parsers = nil
    end)

    -- Ensure the Go parser is properly registered
    local parser_success, go_parser_info =
      pcall(ts_parsers.get_parser_info, "go")
    if not parser_success or not go_parser_info then
      -- Manually register the Go parser if it's not found
      pcall(function()
        if ts_parsers.filetype_to_parsername then
          ts_parsers.filetype_to_parsername.go = "go"
        end
      end)
    end
  end

  -- Verify treesitter can create a parser for Go
  local can_create_parser = pcall(function()
    local ts = vim.treesitter
    if ts and ts.get_parser then
      return ts.get_parser
    end
    return nil
  end)

  if not can_create_parser then
    print("Warning: treesitter parser functionality may not be available")
  end

  -- Do not initialize Neotest here to avoid affecting unit tests
  -- The integration tests will set up neotest as needed

  -- Check if PlenaryBustedFile command is available
  if vim.fn.exists(":PlenaryBustedFile") == 0 then
    error(
      "PlenaryBustedFile command not found. Plenary may not be properly loaded."
    )
  end
end

M.init()
