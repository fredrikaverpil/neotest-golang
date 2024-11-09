--- DAP (manual dap configuration) setup related functions.

local options = require("neotest-golang.options")
local logger = require("neotest-golang.logging")

local dap = require("dap")

local M = {}

---@param cwd string
function M.setup_debugging(cwd)
  local dap_manual_configuration = options.get().dap_manual_configuration or {}
  if type(dap_manual_configuration) == "function" then
    dap_manual_configuration = dap_manual_configuration()
  end

  dap_manual_configuration.cwd = cwd
end

---This will setup a dap configuration to run tests
---@param test_path string
---@param test_name_regex string?
---@return table | nil
function M.get_dap_config(test_path, test_name_regex)
  local dap_manual_configuration = options.get().dap_manual_configuration or {}
  if type(dap_manual_configuration) == "function" then
    dap_manual_configuration = dap_manual_configuration()
  end

  dap_manual_configuration.program = test_path

  if test_name_regex ~= nil then
    dap_manual_configuration.args = dap_manual_configuration.args or {}
    table.insert(dap_manual_configuration.args, "-test.run")
    table.insert(dap_manual_configuration.args, test_name_regex)
  end
  return dap_manual_configuration
end

---Dummy function is needed to be corresponding to dap-go setup (just like trait implementation)
function M.assert_dap_prerequisites()
  logger.debug("Nothing to check. Manual DAP configuration in use")
end

return M
