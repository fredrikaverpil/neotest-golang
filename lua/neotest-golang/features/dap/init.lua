--- DAP setup related functions.

local options = require("neotest-golang.options")
local logger = require("neotest-golang.logging")

local M = {}

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

---@param cwd string
function M.setup_debugging(cwd)
  local dap_impl = get_dap_implementation()
  dap_impl.setup_debugging(cwd)
end

--- @param test_path string
--- @param test_name_regex string?
--- @return table | nil
function M.get_dap_config(test_path, test_name_regex)
  local dap_impl = get_dap_implementation()
  return dap_impl.get_dap_config(test_path, test_name_regex)
end

function M.assert_dap_prerequisites()
  local dap_impl = get_dap_implementation()
  dap_impl.assert_dap_prerequisites()
end

return M
