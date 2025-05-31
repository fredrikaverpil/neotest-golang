--- extra_args can provided directly when invoking Neotest.
--- require('neotest').run.run( { vim.fn.expand('%'), extra_args = { go_test_args = { go_test_args = { "-p=1", "-parallel=10" }, }, }, }, )

local M = {}

local extra_args = {}

function M.set(args)
  -- NOTE: we want to ensure that extra_args is not nil, because code in cmd.lua will call
  -- extra_args.go_test_args and we can't be indexing a nil value.
  extra_args = args or {}
end

function M.get()
  return extra_args
end

return M
