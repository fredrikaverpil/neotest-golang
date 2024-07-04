--- Helpers to build the command and context around running all tests of a file.

local M = {}

--- Build runspec for a directory.
--- @param pos neotest.Position
--- @param tree neotest.Tree
--- @return neotest.RunSpec | neotest.RunSpec[] | nil
function M.build(pos, tree)
  if vim.tbl_isempty(tree:children()) then
    --- @type RunspecContext
    local context = {
      pos_id = pos.id,
      pos_type = "test", -- TODO: to be implemented as "file" later
      golist_output = {}, -- no golist output
      parse_test_results = true,
      test_execution_skipped = true,
    }

    --- Runspec designed for files that contain no tests.
    --- @type neotest.RunSpec
    local run_spec = {
      command = { "echo", "No tests found in file" },
      context = context,
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
