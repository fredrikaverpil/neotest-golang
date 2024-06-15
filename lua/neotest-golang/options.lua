-- These are the default options for neotest-golang. You can override them by
-- providing them as arguments to the Adapter function. See the README for mode
-- details and examples.

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

return M
