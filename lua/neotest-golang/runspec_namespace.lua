local M = {}

--- Build runspec for a namespace.
--- @param pos neotest.Position
--- @return neotest.RunSpec | neotest.RunSpec[] | nil
function M.build(pos)
  -- vim.notify(vim.inspect(pos), vim.levels.log.DEBUG) -- FIXME: remove when done implementing/debugging

  -- TODO: Implement a runspec for a namespace of tests.
  -- A bare return will delegate test execution to per-test execution, which
  -- will have to do for now.
  return
end

return M
