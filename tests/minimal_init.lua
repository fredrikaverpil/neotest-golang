local M = {}

function M.init()
  vim.cmd([[set runtimepath=$VIMRUNTIME]])
  vim.opt.runtimepath:append(".")
  vim.opt.swapfile = false

  vim.opt.packpath = {
    ".tests/all/site",
  }

  vim.cmd([[
      packadd plenary.nvim
      packadd neotest
      packadd nvim-nio
      packadd nvim-treesitter
    ]])

  require("nvim-treesitter.configs").setup({
    ensure_installed = { "go", "lua" }, -- This will install go and lua parsers
    auto_install = true,
    sync_install = true,
  })
end

-- Ensure the required Neovim plugins are installed/cloned
os.execute("tests/install.sh")

M.init()
