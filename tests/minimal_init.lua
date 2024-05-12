local M = {}

-- function M.root(root)
--   local f = debug.getinfo(1, "S").source:sub(2)
--   return vim.fn.fnamemodify(f, ":p:h:h") .. "/" .. (root or "")
-- end

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
