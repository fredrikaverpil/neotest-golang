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
  M.race_detection_enabled_without_cgo_enabled()

  start("DAP (optional)")
  M.binary_found_on_path("dlv")
  M.is_plugin_available("dap")
  M.is_plugin_available("dapui")
  M.is_plugin_available("dap-go")

  start("Gotestsum (optional)")
  M.gotestsum_recommended_on_windows()
  M.gotestsum_installed_but_not_used()

  start("Sanitization (optional)")
  M.sanitization_enabled_but_no_utf8_lib()
end

function M.binary_found_on_path(executable, supress_warn)
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
    if supress_warn then
      ok("Binary '" .. executable .. "' not found on PATH")
    else
      warn("Binary '" .. executable .. "' not found on PATH")
    end
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

local function is_windows_uname()
  local os_info = vim.uv.os_uname()
  return os_info.sysname:lower():find("windows") ~= nil
end

local function is_macos_uname()
  local os_info = vim.uv.os_uname()
  return os_info.sysname:lower():find("darwin") ~= nil
end

function M.race_detection_enabled_without_cgo_enabled()
  if is_macos_uname() then
    -- https://tip.golang.org/doc/go1.20#cgo mentions how this is not a problem on macOS since go 1.20
    return
  end

  local is_cgo_enabled = true
  local env_cgo_enabled = vim.fn.getenv("CGO_ENABLED")
  if env_cgo_enabled == vim.NIL or env_cgo_enabled == "0" then
    is_cgo_enabled = false
  end

  local go_test_args = options.get().go_test_args
  local has_race_detection = false
  for _, value in ipairs(go_test_args) do
    if value == "-race" then
      has_race_detection = true
    end
  end

  if has_race_detection and not is_cgo_enabled then
    error("CGO_ENABLED is disabled but -race is part of go_test_args.")
  end
end

function M.gotestsum_recommended_on_windows()
  if is_windows_uname() then
    if options.get().runner ~= "gotestsum" then
      warn(
        "On Windows, gotestsum runner is recommended for increased stability."
          .. " See the README for linkts to issues/discussions and more info."
      )
    else
      ok("On Windows and with gotestsum set up as runner.")
    end
  end
end

function M.gotestsum_installed_but_not_used()
  local found = M.binary_found_on_path("gotestsum", true)

  -- found but not active
  if found and options.get().runner ~= "gotestsum" then
    local msg = "Found gotestsum to be installed, but not set as test runner."
    if is_windows_uname() then
      warn(msg)
    else
      info(msg)
    end

  -- found and active
  elseif found and options.get().runner == "gotestsum" then
    ok("Tests will be executed by gotestsum.")
  end
end

function M.sanitization_enabled_but_no_utf8_lib()
  if options.get().sanitization then
    local is_installed = pcall(require, "utf8")
    if is_installed then
      ok("utf8.nvim is available")
    else
      warn("utf8.nvim is not available")
    end
  end
  ok("Sanitization is disabled")
end

return M
