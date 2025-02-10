--- These are the default options for neotest-golang. You can override them by
--- providing them as arguments to the Adapter function. See the README for mode
--- details and examples.

local logger = require("neotest-golang.logging")

local M = {}

local opts = {
  runner = "go", -- or "gotestsum"
  go_test_args = { "-v", "-race", "-count=1" }, -- NOTE: can also be a function
  gotestsum_args = { "--format=standard-verbose" }, -- NOTE: can also be a function
  go_list_args = {}, -- NOTE: can also be a function
  dap_go_opts = {}, -- NOTE: can also be a function
  dap_mode = "dap-go", -- NOTE: or "manual" ; can also be a function
  dap_manual_config = {}, -- NOTE: can also be a function
  testify_enabled = false,
  testify_operand = "^(s|suite)$",
  testify_import_identifier = "^(suite)$",
  colorize_test_output = true,
  warn_test_name_dupes = true,
  warn_test_not_executed = true,
  log_level = vim.log.levels.WARN,
  sanitize_output = false,

  -- experimental, for now undocumented, options
  dev_notifications = false,
}

function M.setup(user_opts)
  if type(user_opts) == "table" and not vim.tbl_isempty(user_opts) then
    for k, v in pairs(user_opts) do
      opts[k] = v
    end
  else
  end
  logger.debug("Loaded with options: " .. vim.inspect(opts))
end

function M.get()
  return opts
end

function M.set(updated_opts)
  for k, v in pairs(updated_opts) do
    opts[k] = v
  end
  return opts
end

return M
