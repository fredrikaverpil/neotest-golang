local start = vim.health.start or vim.health.report_start
local ok = vim.health.ok or vim.health.report_ok
local warn = vim.health.warn or vim.health.report_warn
local error = vim.health.error or vim.health.report_error
local info = vim.health.info or vim.health.report_info

local lib = require("neotest-golang.lib")
local options = require("neotest-golang.options")
local query_loader = require("neotest-golang.lib.query_loader")

local M = {}

function M.check()
  start("System Information")
  M.operating_system_info()

  start("Requirements")
  M.neovim_version_check()
  M.binary_found_on_path("go")
  M.go_version_check()
  M.go_mod_found()
  M.is_problematic_path()
  M.treesitter_parser_installed("go")
  M.treesitter_queries_compatible()
  M.is_plugin_available("neotest")
  M.is_plugin_available("nio")
  M.is_plugin_available("plenary")
  M.race_detection_enabled_without_cgo_enabled()

  start("nvim-treesitter (optional)")
  M.is_plugin_available("nvim-treesitter")
  M.nvim_treesitter_branch_check()

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

  start("Configuration")
  M.display_current_configuration()
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
    local start_path = lib.path.get_directory(filepath)
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
    local start_path = lib.path.get_directory(filepath)
    go_mod_filepath = lib.find.file_upwards("go.mod", start_path)
    local sysname = vim.uv.os_uname().sysname
    local problematic_paths = {
      Darwin = {
        "/private/tmp",
        "/tmp",
        lib.path.normalize_path(os.getenv("HOME") .. "/Public"),
      },
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
  local has_parser = pcall(vim.treesitter.language.add, lang)
  if has_parser then
    ok("Treesitter parser for " .. lang .. " is installed")
    return true
  else
    error("Treesitter parser for " .. lang .. " is not installed")
    return false
  end
end

function M.treesitter_queries_compatible()
  -- Skip if parser isn't available
  local parser_ok = pcall(vim.treesitter.language.add, "go")
  if not parser_ok then
    warn("Skipping query compatibility check (Go parser not available)")
    return false
  end

  -- Core queries that must work for basic functionality
  local queries_to_check = {
    { name = "test_function", path = "queries/go/test_function.scm" },
    { name = "table_tests_list", path = "queries/go/table_tests_list.scm" },
    { name = "table_tests_loop", path = "queries/go/table_tests_loop.scm" },
    {
      name = "table_tests_unkeyed",
      path = "queries/go/table_tests_unkeyed.scm",
    },
    {
      name = "table_tests_loop_unkeyed",
      path = "queries/go/table_tests_loop_unkeyed.scm",
    },
    { name = "table_tests_map", path = "queries/go/table_tests_map.scm" },
    {
      name = "table_tests_inline_field_access",
      path = "queries/go/table_tests_inline_field_access.scm",
    },
  }

  -- Also check testify queries if enabled
  if options.get().testify_enabled then
    table.insert(queries_to_check, {
      name = "testify/namespace",
      path = "features/testify/queries/go/namespace.scm",
    })
    table.insert(queries_to_check, {
      name = "testify/test_method",
      path = "features/testify/queries/go/test_method.scm",
    })
  end

  local all_ok = true
  local failed_queries = {}

  for _, q in ipairs(queries_to_check) do
    local load_ok, query_str = pcall(query_loader.load_query, q.path)
    if not load_ok then
      all_ok = false
      table.insert(
        failed_queries,
        { name = q.name, err = "Could not load query file" }
      )
    else
      local parse_ok, err = pcall(vim.treesitter.query.parse, "go", query_str)
      if not parse_ok then
        all_ok = false
        -- Extract useful info from error message
        local err_msg = tostring(err)
        -- Try to find the invalid node type from error like "Invalid node type 'xyz'"
        local invalid_node = err_msg:match("Invalid node type '([^']+)'")
          or err_msg:match("invalid node type '([^']+)'")
        if invalid_node then
          table.insert(
            failed_queries,
            { name = q.name, err = "Unknown node type: " .. invalid_node }
          )
        else
          table.insert(failed_queries, { name = q.name, err = err_msg })
        end
      end
    end
  end

  if all_ok then
    ok("All tree-sitter queries are compatible with your Go parser")
  else
    for _, failed in ipairs(failed_queries) do
      error("Query '" .. failed.name .. "' incompatible: " .. failed.err)
    end
    warn(
      "Tree-sitter query/parser mismatch. Either update your Go parser "
        .. "with :TSUpdate go, or update neotest-golang to the latest version."
    )
  end

  return all_ok
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
  else
    ok("Sanitization is disabled")
  end
end

function M.neovim_version_check()
  local version = vim.version()
  local version_str =
    string.format("%d.%d.%d", version.major, version.minor, version.patch)

  if version.major > 0 or (version.major == 0 and version.minor >= 10) then
    ok("Neovim version " .. version_str .. " is supported (>= 0.10.0)")
  else
    error(
      "Neovim version "
        .. version_str
        .. " is not supported (requires >= 0.10.0)"
    )
  end
end

function M.go_version_check()
  if vim.fn.executable("go") == 1 then
    local cmd = "go version"
    -- Add appropriate error redirection based on OS
    if is_windows_uname() then
      cmd = cmd .. " 2>nul"
    else
      cmd = cmd .. " 2>/dev/null"
    end

    local handle = io.popen(cmd)
    if handle then
      local result = handle:read("*a")
      handle:close()
      if result and result ~= "" then
        local version_info = result:gsub("\n", "")
        ok("Go version: " .. version_info)
      else
        warn("Could not determine Go version")
      end
    else
      warn("Could not execute 'go version' command")
    end
  end
end

function M.nvim_treesitter_branch_check()
  if not pcall(require, "nvim-treesitter") then
    return
  end

  -- Try multiple common installation paths
  local potential_paths = {
    vim.fn.stdpath("data") .. "/lazy/nvim-treesitter",
    vim.fn.stdpath("data") .. "/site/pack/packer/start/nvim-treesitter",
    vim.fn.stdpath("data") .. "/site/pack/packer/opt/nvim-treesitter",
    vim.fn.stdpath("config") .. "/pack/*/start/nvim-treesitter",
    vim.fn.stdpath("config") .. "/pack/*/opt/nvim-treesitter",
  }

  local ts_path = nil
  for _, path in ipairs(potential_paths) do
    if path:find("%*") then
      -- Handle glob patterns
      local matches = vim.fn.glob(path, false, true)
      if #matches > 0 then
        ts_path = matches[1]
        break
      end
    else
      -- Direct path check
      if vim.fn.isdirectory(path) == 1 then
        ts_path = path
        break
      end
    end
  end

  if not ts_path then
    info("Could not locate nvim-treesitter installation path")
    return
  end

  -- Check for files that distinguish main vs master branch
  local main_indicators =
    { "lua/nvim-treesitter/async.lua", "lua/nvim-treesitter/config.lua" }
  local master_indicators = {
    "lua/nvim-treesitter/configs.lua",
    "lua/nvim-treesitter/query.lua",
    "lua/nvim-treesitter/locals.lua",
  }

  local has_main_files = false
  local has_master_files = false

  for _, file in ipairs(main_indicators) do
    if vim.fn.filereadable(ts_path .. "/" .. file) == 1 then
      info("Found " .. ts_path .. " (main)")
      has_main_files = true
      break
    end
  end

  for _, file in ipairs(master_indicators) do
    if vim.fn.filereadable(ts_path .. "/" .. file) == 1 then
      info("Found " .. ts_path .. " (master)")
      has_master_files = true
      break
    end
  end

  if has_main_files and not has_master_files then
    ok(
      "nvim-treesitter appears to be on 'main' branch (recommended for neotest-golang v2+)"
    )
  elseif has_master_files and not has_main_files then
    error(
      "nvim-treesitter appears to be on 'master' branch (neotest-golang v2+ requires 'main' branch)"
    )
  elseif has_main_files and has_master_files then
    warn(
      "nvim-treesitter branch detection inconclusive (found indicators for both branches)"
    )
  else
    warn(
      "Could not determine nvim-treesitter branch (no known indicators found in "
        .. ts_path
        .. ")"
    )
  end
end

function M.operating_system_info()
  local os_info = vim.uv.os_uname()
  local sysname = os_info.sysname
  local release = os_info.release or ""
  local version = os_info.version or ""

  -- Basic OS detection
  local os_display = sysname
  local additional_info = {}

  -- Windows detection
  if sysname:lower():find("windows") then
    os_display = "Windows"
    if release ~= "" then
      table.insert(additional_info, "Version: " .. release)
    end

  -- macOS detection
  elseif sysname:lower():find("darwin") then
    os_display = "macOS"
    if release ~= "" then
      table.insert(additional_info, "Kernel: " .. release)
    end

  -- Linux detection (including WSL)
  elseif sysname:lower():find("linux") then
    local is_wsl = false
    local wsl_info = ""

    -- Check for WSL
    local proc_version_file = io.open("/proc/version", "r")
    if proc_version_file then
      local proc_version = proc_version_file:read("*a")
      proc_version_file:close()

      if
        proc_version:lower():find("microsoft")
        or proc_version:lower():find("wsl")
      then
        is_wsl = true
        if proc_version:lower():find("wsl2") then
          wsl_info = "WSL2"
        else
          wsl_info = "WSL1"
        end
      end
    end

    -- Try to get Linux distribution info
    local distro_info = ""
    local os_release_file = io.open("/etc/os-release", "r")
    if os_release_file then
      local content = os_release_file:read("*a")
      os_release_file:close()

      -- Look for PRETTY_NAME first, then NAME
      local pretty_name = content:match('PRETTY_NAME="([^"]*)"')
      if pretty_name then
        distro_info = pretty_name
      else
        local name = content:match('NAME="([^"]*)"')
        if name then
          distro_info = name
        end
      end
    end

    -- Build display string
    if is_wsl then
      if distro_info ~= "" then
        os_display = wsl_info .. " (" .. distro_info .. ")"
      else
        os_display = wsl_info .. " (Linux)"
      end
    else
      if distro_info ~= "" then
        os_display = distro_info
      else
        os_display = "Linux"
      end
    end

    if release ~= "" then
      table.insert(additional_info, "Kernel: " .. release)
    end

  -- Other Unix-like systems
  else
    os_display = sysname
    if release ~= "" then
      table.insert(additional_info, "Release: " .. release)
    end
  end

  -- Display the information
  local main_info = "Operating System: " .. os_display
  ok(main_info)

  -- Display additional info if available
  for _, info_text in ipairs(additional_info) do
    info("  " .. info_text)
  end
end

function M.display_current_configuration()
  local current_options = options.get()
  info(vim.inspect(current_options))
end

return M
