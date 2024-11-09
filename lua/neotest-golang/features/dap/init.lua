--- DAP setup related functions.

local options = require("neotest-golang.options")
local dap_manual = require("neotest-golang.features.dap.dap_manual")
local dap_go = require("neotest-golang.features.dap.dap_go")

local M = {}

local function is_dap_manual_enabled()
  local dap_manual_enabled = options.get().dap_manual_enabled
  if type(dap_manual_enabled) == "function" then
    dap_manual_enabled = dap_manual_enabled()
  end
  return dap_manual_enabled
end

---@param cwd string
function M.setup_debugging(cwd)
  if is_dap_manual_enabled() then
    dap_manual.setup_debugging(cwd)
  else
    dap_go.setup_debugging(cwd)
  end
end

--- @param test_path string
--- @param test_name_regex string?
--- @return table | nil
function M.get_dap_config(test_path, test_name_regex)
  if is_dap_manual_enabled() then
    return dap_manual.get_dap_config(test_path, test_name_regex)
  else
    return dap_go.get_dap_config(test_path, test_name_regex)
  end
end

function M.assert_dap_prerequisites()
  if is_dap_manual_enabled() then
    dap_manual.assert_dap_prerequisites()
  else
    dap_go.assert_dap_prerequisites()
  end
end

return M
