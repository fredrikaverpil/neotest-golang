--- DAP setup related functions.

local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")

---@class DapConfig
---@field type string DAP adapter type (e.g., "go")
---@field request string DAP request type (e.g., "launch")
---@field mode string DAP mode (e.g., "test", "debug")
---@field program string Path to program to debug
---@field args? string[] Optional arguments to pass to the program
---@field env? table<string, string> Optional environment variables

local M = {}

--- Get the DAP implementation based on configured mode
--- @return table DAP implementation module
local function get_dap_implementation()
  local dap_impl
  local selected_dap_mode = options.get().dap_mode
  if type(selected_dap_mode) == "function" then
    selected_dap_mode = selected_dap_mode()
  end

  if selected_dap_mode == "dap-go" then
    dap_impl = require("neotest-golang.features.dap.dap_go")
  elseif selected_dap_mode == "manual" then
    dap_impl = require("neotest-golang.features.dap.dap_manual")
  else
    local msg = "Got dap-mode: `"
      .. selected_dap_mode
      .. "` that cannot be used. "
      .. "See the neotest-golang README for more information."
    logger.error(msg)
    error(msg)
  end

  return dap_impl
end

--- Setup debugging environment for the given directory
---@param cwd string Working directory for debugging session
function M.setup_debugging(cwd)
  local dap_impl = get_dap_implementation()
  dap_impl.setup_debugging(cwd)
end

--- Get DAP configuration for debugging tests
--- @param test_path string Directory path containing tests
--- @param test_name_regex string|nil Optional regex to match specific tests
--- @return DapConfig|nil DAP configuration table or nil if unavailable
function M.get_dap_config(test_path, test_name_regex)
  local dap_impl = get_dap_implementation()
  return dap_impl.get_dap_config(test_path, test_name_regex)
end

--- Assert that DAP prerequisites are met for debugging
--- @return nil Throws error if prerequisites not met
function M.assert_dap_prerequisites()
  local dap_impl = get_dap_implementation()
  dap_impl.assert_dap_prerequisites()
end

return M
