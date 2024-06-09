local options = require("neotest-golang.options")
local discover_positions = require("neotest-golang.discover_positions")
local runspec_test = require("neotest-golang.runspec_test")
local results_test = require("neotest-golang.results_test")
local utils = require("neotest-golang.utils")

local M = {}

---See neotest.Adapter for the full interface.
---@class Adapter : neotest.Adapter
---@field name string
M.Adapter = {
  name = "neotest-golang",
}

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param dir string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
function M.Adapter.root(dir)
  -- Since neotest-golang is setting the cwd prior to running tests or debugging
  -- we can use the cwd as-is and treat it as the root.
  return dir
end

---Filter directories when searching for test files
---@async
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@param root string Root directory of project
---@return boolean
function M.Adapter.filter_dir(name, rel_path, root)
  local ignore_dirs = { ".git", "node_modules", ".venv", "venv" }
  for _, ignore in ipairs(ignore_dirs) do
    if name == ignore then
      return false
    end
  end
  return true
end

---@async
---@param file_path string
---@return boolean
function M.Adapter.is_test_file(file_path)
  return vim.endswith(file_path, "_test.go")
end

---Given a file path, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function M.Adapter.discover_positions(file_path)
  return discover_positions.discover_positions(file_path)
end

---Build the runspec, which describes how to execute the test(s).
---NOTE: right now, this test function is delegating any test execution on
---a per-test basis.
---
---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function M.Adapter.build_spec(args)
  ---@type neotest.Tree
  local tree = args.tree
  ---@type neotest.Position
  local pos = args.tree:data()

  if not tree then
    vim.notify("Error: [build_spec] not a tree!", vim.log.levels.ERROR)
    return
  end

  if pos.type == "dir" and pos.path == vim.fn.getcwd() then
    -- Test suite

    return -- delegate test execution to per-test execution
  elseif pos.type == "dir" then
    -- Sub-directory

    return -- delegate test execution to per-test execution
  elseif pos.type == "file" then
    -- Single file

    if utils.table_is_empty(tree:children()) then
      -- No tests present in file
      ---@type neotest.RunSpec
      local run_spec = {
        command = { "echo", "No tests found in file" },
        context = {
          id = pos.id,
          skip = true,
          test_type = "test", -- TODO: to be implemented as "file" later
        },
      }
      return run_spec
    else
      -- Go does not run tests based on files, but on the package name. If Go
      -- is given a filepath, in which tests resides, it also needs to have all
      -- other filepaths that might be related passed as arguments to be able
      -- to compile. This approach is too brittle, and therefore this mode is not
      -- supported. Instead, the tests of a file are run as if pos.typ == "test".

      return -- delegate test execution to per-test execution
    end
  elseif pos.type == "test" then
    -- Single test
    return runspec_test.build(pos, args.strategy)
  else
    vim.notify("Error: [build_spec] unknown position type: " .. pos.type)
    return
  end
end

---Parse the test execution results, populate test outcome into the neotest
---node tree.
---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function M.Adapter.results(spec, result, tree)
  return results_test.results_test(spec, result, tree)
end

setmetatable(M.Adapter, {
  __call = function(_, opts)
    return M.Adapter.setup(opts)
  end,
})

M.Adapter.setup = function(opts)
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
      options._go_test_args = opts.go_test_args
    end
    if opts.dap_go_enabled then
      options._dap_go_enabled = opts.dap_go_enabled
      if opts.dap_go_opts then
        options._dap_go_opts = opts.dap_go_opts
      end
    end
  end

  return M.Adapter
end

return M.Adapter
