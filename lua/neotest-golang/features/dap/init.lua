--- DAP setup related functions.

local options = require("neotest-golang.options")
local logger = require("neotest-golang.logging")

local M = {}

---This will prepare and setup nvim-dap-go for debugging.
---@param cwd string
function M.setup_debugging(cwd)
  local dap_go_opts = options.get().dap_go_opts or {}
  if type(dap_go_opts) == "function" then
    dap_go_opts = dap_go_opts()
  end
  local dap_go_opts_original = vim.deepcopy(dap_go_opts)
  if dap_go_opts.delve == nil then
    dap_go_opts.delve = {}
  end
  dap_go_opts.delve.cwd = cwd
  logger.debug({ "Provided dap_go_opts for DAP: ", dap_go_opts })
  require("dap-go").setup(dap_go_opts)

  -- reset nvim-dap-go (and cwd) after debugging with nvim-dap
  require("dap").listeners.after.event_terminated["neotest-golang-debug"] = function()
    logger.debug({
      "Resetting provided dap_go_opts for DAP: ",
      dap_go_opts_original,
    })
    require("dap-go").setup(dap_go_opts_original)
  end
end

--- @param test_name_regex string
--- @return table | nil
function M.get_dap_config(test_name_regex)
  -- :help dap-configuration
  local dap_config = {
    type = "go",
    name = "Neotest-golang",
    request = "launch",
    mode = "test",
    program = "${fileDirname}",
    args = { "-test.run", test_name_regex },
  }

  local dap_go_opts = options.get().dap_go_opts or {}
  if dap_go_opts.delve ~= nil and dap_go_opts.delve.build_flags ~= nil then
    dap_config.buildFlags = dap_go_opts.delve.build_flags
  end

  return dap_config
end

return M
