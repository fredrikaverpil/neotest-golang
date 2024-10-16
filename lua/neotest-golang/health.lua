local start = vim.health.start or vim.health.report_start
local ok = vim.health.ok or vim.health.report_ok
local warn = vim.health.warn or vim.health.report_warn
local error = vim.health.error or vim.health.report_error
local info = vim.health.info or vim.health.report_info

local options = require("neotest-golang.options")
local lib = require("neotest-golang.lib")

local M = {}

function M.check()
  start("Requirements")
  M.binary_found_on_path("go")
  M.go_mod_found()
  M.is_problematic_path()
  M.treesitter_parser_installed("go")
  M.is_plugin_available("neotest")
  M.is_plugin_available("nvim-treesitter")
  M.is_plugin_available("nio")
  M.is_plugin_available("plenary")

  start("DAP (optional)")
  M.binary_found_on_path("dlv")
  M.is_plugin_available("dap")
  M.is_plugin_available("dapui")
  M.is_plugin_available("dap-go")

  start("Gotestsum (optional)")
  M.binary_found_on_path("gotestsum")
end

function M.binary_found_on_path(executable)
  local found = vim.fn.executable(executable)
  if found == 1 then
    ok(
      "Binary '"
        .. executable
        .. "' found on PATH: "
        .. vim.fn.exepath(executable)
    )
    return true
  else
    warn("Binary '" .. executable .. "' not found on PATH")
  end
  return false
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

function M.is_problematic_path()
  local go_mod_filepath = nil
  local filepaths = lib.find.go_test_filepaths(vim.fn.getcwd())
  for _, filepath in ipairs(filepaths) do
    local start_path = vim.fn.fnamemodify(filepath, ":h")
    go_mod_filepath = lib.find.file_upwards("go.mod", start_path)
    local sysname = vim.uv.os_uname().sysname
    local problematic_paths = {
      Darwin = { "/private/tmp", "/tmp", vim.fs.normalize("~/Public") },
      Linux = { "/tmp" },
    }
    if problematic_paths[sysname] == nil then
      return
    end
    for _, problematic_path in ipairs(problematic_paths[sysname]) do
      if go_mod_filepath ~= nil and go_mod_filepath:find(problematic_path) then
        warn(
          "Path reportedly problematic: "
            .. problematic_path
            .. " (try another path if you experience issues)"
        )
        return
      end
    end
  end
end

function M.is_plugin_available(plugin)
  local is_plugin_available = pcall(require, plugin)
  if is_plugin_available then
    ok(plugin .. " is available")
  else
    warn(plugin .. " is not available")
  end
end

function M.treesitter_parser_installed(lang)
  local is_installed = require("nvim-treesitter.parsers").has_parser(lang)
  if is_installed then
    ok("Treesitter parser for " .. lang .. " is installed")
  else
    warn("Treesitter parser for " .. lang .. " is not installed")
  end
end

return M
