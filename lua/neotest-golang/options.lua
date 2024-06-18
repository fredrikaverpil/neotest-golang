--- These are the default options for neotest-golang. You can override them by
--- providing them as arguments to the Adapter function. See the README for mode
--- details and examples.

local Opts = {}

--- Create a new options object.
function Opts:new(opts)
  self.go_test_args = opts.go_test_args
    or {
      "-v",
      "-race",
      "-count=1",
      "-timeout=60s",
    }
  self.dap_go_enabled = opts.dap_go_enabled or false
  self.dap_go_opts = opts.dap_go_opts or {}
end

--- A convenience function to get the current options.
function Opts:get()
  return {
    go_test_args = self.go_test_args,
    dap_go_enabled = self.dap_go_enabled,
    dap_go_opts = self.dap_go_opts,
  }
end

local M = {}

--- Set up the adapter.
function M.setup(opts)
  opts = opts or {}
  Opts:new(opts)
  return Opts:get()
end

--- Get the adapter configuration.
function M.get()
  return Opts:get()
end

return M
