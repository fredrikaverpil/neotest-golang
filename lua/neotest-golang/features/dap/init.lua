--- DAP setup related functions.

local options = require("neotest-golang.options")

local M = {}

local function is_dap_manual_enabled()
  local dap_manual_enabled = options.get().dap_manual_enabled
  if type(dap_manual_enabled) == "function" then
    dap_manual_enabled = dap_manual_enabled()
  end
  return dap_manual_enabled
end

local function get_dap_implementation()
  local dap_impl
  if is_dap_manual_enabled() then
    dap_impl = require("neotest-golang.features.dap.dap_manual")
  else
    dap_impl = require("neotest-golang.features.dap.dap_go")
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
