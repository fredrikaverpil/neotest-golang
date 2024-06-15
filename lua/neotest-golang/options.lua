--- These are the default options for neotest-golang. You can override them by
--- providing them as arguments to the Adapter function. See the README for mode
--- details and examples.

local M = {}

--- Arguments to pass into `go test`. Will be combined with arguments required
--- for neotest-golang to work and execute the expected test(s).
--- @type table
M._go_test_args = {
  "-v",
  "-race",
  "-count=1",
  "-timeout=60s",
}

--- Whether to enable nvim-dap-go.
--- @type boolean
M._dap_go_enabled = false

--- Options to pass into dap-go.setup.
--- @type table
M._dap_go_opts = {}

--- Option setup function. This is what you call when setting up the adapter.
--- @param opts table
function M.setup(opts)
  opts = opts or {}
  if opts.args or opts.dap_go_args then
    -- temporary warning
    vim.notify(
      "Please update your config, the arguments/opts have changed for neotest-golang.",
      vim.log.levels.WARN
    )
  end
  if opts.go_test_args then
    if opts.go_test_args then
      M._go_test_args = opts.go_test_args
    end
    if opts.dap_go_enabled then
      M._dap_go_enabled = opts.dap_go_enabled
      if opts.dap_go_opts then
        M._dap_go_opts = opts.dap_go_opts
      end
    end
  end

  return M.Adapter
end

return M
