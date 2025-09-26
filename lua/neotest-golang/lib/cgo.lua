--- CGO and C compiler detection utilities for validating -race flag requirements.

local logger = require("neotest-golang.lib.logging")

local M = {}

--- Check if the provided arguments contain the -race flag
--- @param args string[] Arguments to check
--- @return boolean True if -race flag is present
function M.has_race_flag(args)
  if not args then
    return false
  end
  for _, arg in ipairs(args) do
    if arg == "-race" then
      return true
    end
  end
  return false
end

--- Get the C compiler command from Go environment
--- @return string|nil C compiler command if available
function M.get_go_c_compiler()
  local result = vim.system({ "go", "env", "CC" }, { text = true }):wait()
  if result.code == 0 and result.stdout then
    local cc = vim.trim(result.stdout)
    if cc and cc ~= "" then
      return cc
    end
  end
  return nil
end

--- Check if CGO is enabled in the environment
--- @return boolean True if CGO is enabled
function M.is_cgo_enabled()
  local cgo_enabled = vim.env.CGO_ENABLED
  if cgo_enabled == nil then
    -- CGO_ENABLED defaults to 1 if not set
    return true
  end
  return cgo_enabled == "1"
end

--- Check if an executable is available in the system PATH
--- @param executable string Name of the executable to check
--- @return boolean True if executable is found and executable
local function system_has(executable)
  if vim.fn.executable(executable) == 0 then
    logger.warn("Executable not found: " .. executable, true)
    return false
  end
  return true
end

--- Check if a C compiler is available for CGO
--- @return boolean True if a C compiler is available
function M.has_c_compiler()
  -- First try the Go-configured C compiler
  local go_cc = M.get_go_c_compiler()
  if go_cc and system_has(go_cc) then
    return true
  end

  -- Fall back to common C compilers
  local common_compilers = { "gcc", "clang", "cc" }
  for _, compiler in ipairs(common_compilers) do
    if system_has(compiler) then
      return true
    end
  end

  return false
end

--- Validate CGO requirements for the -race flag
--- @param args string[] Arguments to validate
--- @return boolean True if validation passes
--- @return string|nil Error message if validation fails
function M.validate_cgo_requirements(args)
  if not M.has_race_flag(args) then
    -- No -race flag, no validation needed
    return true, nil
  end

  if not M.is_cgo_enabled() then
    return false,
      "The -race flag requires CGO to be enabled, but CGO_ENABLED=0. "
        .. "Either remove the -race flag from go_test_args or enable CGO by setting CGO_ENABLED=1. "
        .. "See https://github.com/fredrikaverpil/neotest-golang/blob/main/docs/config.md#go_test_args for more information."
  end

  if not M.has_c_compiler() then
    return false,
      "The -race flag requires a C compiler (GCC, Clang, etc.) to be installed, but none was found. "
        .. "Either remove the -race flag from go_test_args or install a C compiler such as GCC. "
        .. "See https://github.com/fredrikaverpil/neotest-golang/blob/main/docs/config.md#go_test_args for more information."
  end

  return true, nil
end

return M
