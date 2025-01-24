local M = {}

local function normalize_path(path)
  if vim.fn.has("win32") == 1 then
    return path:gsub("\\", "/")
  end
  return path
end

function M.init()
  vim.cmd([[set runtimepath=$VIMRUNTIME]]) -- reset, otherwise it contains all of $PATH
  vim.opt.swapfile = false

  local site_dir = normalize_path(vim.fn.getcwd() .. "/.tests/all/site")
  vim.opt.packpath = { site_dir } -- set packpath to the site directory
end

M.init()
