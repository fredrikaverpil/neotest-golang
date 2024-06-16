local utils = require("neotest-golang.utils")

local M = {}

--- Build runspec for a directory.
--- @param pos neotest.Position
--- @param tree neotest.Tree
--- @return neotest.RunSpec | neotest.RunSpec[] | nil
function M.build(pos, tree)
  if utils.table_is_empty(tree:children()) then
    --- Runspec designed for files that contain no tests.
    --- @type neotest.RunSpec
    local run_spec = {
      command = { "echo", "No tests found in file" },
      context = {
        id = pos.id,
        skip = true,
        pos_type = "test", -- TODO: to be implemented as "file" later
      },
    }
    return run_spec
  else
    -- TODO: Implement a runspec for a file of tests.
    -- A bare return will delegate test execution to per-test execution, which
    -- will have to do for now.
    return
  end
end

return M
