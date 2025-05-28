--- Extra args are provided directly from Neotest.
--- Example:
--- require('neotest').run.run( { vim.fn.expand('%'), extra_args = { go_test_args = { go_test_args = { "-p=1", "-parallel=10" }, }, }, }, )

local M = {}

local extra_args = {}

function M.get()
  return extra_args
end

function M.set(args)
  extra_args = args
  return extra_args
end

return M
