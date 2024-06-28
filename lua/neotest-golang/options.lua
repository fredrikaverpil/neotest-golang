--- These are the default options for neotest-golang. You can override them by
--- providing them as arguments to the Adapter function. See the README for mode
--- details and examples.

local M = {}

local opts = {
  go_test_args = {
    "-v",
    "-race",
    "-count=1",
  },
  dap_go_enabled = false,
  dap_go_opts = {},
  warn_test_name_dupes = true,
  warn_test_not_executed = true,
  dev_notifications = false,
}

function M.setup(user_opts)
  if type(user_opts) == "table" and not vim.tbl_isempty(user_opts) then
    for k, v in pairs(user_opts) do
      opts[k] = v
    end
  else
  end
end

function M.get()
  return opts
end

return M
