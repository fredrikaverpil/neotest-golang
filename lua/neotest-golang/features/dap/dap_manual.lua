--- DAP (manual dap configuration) setup related functions.

local options = require("neotest-golang.options")

local M = {}

---@param cwd string
function M.setup_debugging(cwd)
  local dap_manual_config = options.get().dap_manual_config or {}
  if type(dap_manual_config) == "function" then
    dap_manual_config = dap_manual_config()
  end

  dap_manual_config.cwd = cwd
end

---This will setup a dap configuration to run tests
---@param test_path string
---@param test_name_regex string?
---@return table | nil
function M.get_dap_config(test_path, test_name_regex)
  local dap_manual_config = options.get().dap_manual_config or {}
  if type(dap_manual_config) == "function" then
    dap_manual_config = dap_manual_config()
  end

  dap_manual_config.program = test_path

  if test_name_regex ~= nil then
    dap_manual_config.args = dap_manual_config.args or {}
    table.insert(dap_manual_config.args, "-test.run")
    table.insert(dap_manual_config.args, test_name_regex)
  end
  return dap_manual_config
end

---Dummy function is needed to be corresponding to dap-go setup (just like trait implementation)
function M.assert_dap_prerequisites() end

return M
