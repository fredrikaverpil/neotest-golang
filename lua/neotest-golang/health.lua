local start = vim.health.start or vim.health.report_start
local ok = vim.health.ok or vim.health.report_ok
local warn = vim.health.warn or vim.health.report_warn
local error = vim.health.error or vim.health.report_error
local info = vim.health.info or vim.health.report_info

local options = require("neotest-golang.options")
local lib = require("neotest-golang.lib")

local M = {}

function M.check()
  M.go_binary_on_path()
  M.go_mod_found()
end

function M.go_binary_on_path()
  local go = vim.fn.executable("go")
  if go == 1 then
    ok("Go binary found on PATH: " .. vim.fn.exepath("go"))
  else
    warn("Go binary not found on PATH")
  end
end

function M.go_mod_found()
  local go_mod_filepath = nil
  local filepaths = lib.find.go_test_filepaths(vim.fn.getcwd())
  for _, filepath in ipairs(filepaths) do
    local start_path = vim.fn.fnamemodify(filepath, ":h")
    go_mod_filepath = lib.find.file_upwards("go.mod", start_path)
    if go_mod_filepath ~= nil then
      ok("Found go.mod file for " .. filepath .. " in " .. go_mod_filepath)
      break
    end
  end
  if go_mod_filepath == nil then
    warn("No go.mod file found")
  end
end

return M
