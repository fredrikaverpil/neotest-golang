--- These are the default options for neotest-golang. You can override them by
--- providing them as arguments to the Adapter function. See the README for mode
--- details and examples.

local logger = require("neotest-golang.logging")

---@class NeotestGolangOptions
---@field runner string "go" or "gotestsum"
---@field go_test_args string[]|fun(): string[] Arguments for go test command
---@field gotestsum_args string[]|fun(): string[] Arguments for gotestsum command
---@field go_list_args string[]|fun(): string[] Arguments for go list command
---@field dap_go_opts table|fun(): table DAP configuration for dap-go
---@field dap_mode string|fun(): string "dap-go" or "manual"
---@field dap_manual_config table|fun(): table Manual DAP configuration
---@field env table|fun(): table Environment variables
---@field testify_enabled boolean Enable testify suite support
---@field testify_operand string Regex pattern for testify suite variables
---@field testify_import_identifier string Regex pattern for testify import identifiers
---@field colorize_test_output boolean Enable colored test output
---@field warn_test_name_dupes boolean Warn about duplicate test names
---@field warn_test_not_executed boolean Warn about tests not executed
---@field warn_test_results_missing boolean Warn about missing test results
---@field log_level integer Vim log level
---@field sanitize_output boolean Sanitize test output
---@field dev_notifications boolean Enable development notifications (experimental)

local M = {}

---@type NeotestGolangOptions
local opts = {
  runner = "go", -- or "gotestsum"
  go_test_args = { "-v", "-race", "-count=1" }, -- NOTE: can also be a function
  gotestsum_args = { "--format=standard-verbose" }, -- NOTE: can also be a function
  go_list_args = {}, -- NOTE: can also be a function
  dap_go_opts = {}, -- NOTE: can also be a function
  dap_mode = "dap-go", -- NOTE: or "manual" ; can also be a function
  dap_manual_config = {}, -- NOTE: can also be a function
  env = {}, -- NOTE: can also be a function
  testify_enabled = false,
  testify_operand = "^(s|suite)$",
  testify_import_identifier = "^(suite)$",
  colorize_test_output = true,
  warn_test_name_dupes = true, -- TODO: not implemented yet
  warn_test_not_executed = true, -- TODO: not implemented yet
  warn_test_results_missing = true,
  log_level = vim.log.levels.WARN,
  sanitize_output = false,

  -- experimental, for now undocumented, options
  dev_notifications = false,
}

---@param user_opts NeotestGolangOptions?
function M.setup(user_opts)
  if type(user_opts) == "table" and not vim.tbl_isempty(user_opts) then
    for k, v in pairs(user_opts) do
      opts[k] = v
    end
  else
  end
  logger.debug("Loaded with options: " .. vim.inspect(opts))
end

---@return NeotestGolangOptions
function M.get()
  return opts
end

---@param updated_opts NeotestGolangOptions
---@return NeotestGolangOptions
function M.set(updated_opts)
  for k, v in pairs(updated_opts) do
    opts[k] = v
  end
  return opts
end

return M
