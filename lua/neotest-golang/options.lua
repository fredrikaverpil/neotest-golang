--- These are the default options for neotest-golang. You can override them by
--- providing them as arguments to the Adapter function. See the README for mode
--- details and examples.

local M = {}

local opts = {
  go_test_args = { "-v", "-race", "-count=1" },
  dap_go_enabled = false,
  dap_go_opts = {},
  testify_enabled = false,
  warn_test_name_dupes = true,

  -- experimental, for now undocumented, options
  runner = "go", -- or "gotestsum"
  gotestsum_args = { "--format=standard-verbose" },
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

function M.set(updated_opts)
  for k, v in pairs(updated_opts) do
    opts[k] = v
  end
  return opts
end

return M
