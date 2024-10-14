--- This is the main entry point for the neotest-golang adapter. It follows the
--- Neotest interface: https://github.com/nvim-neotest/neotest/blob/master/lua/neotest/adapters/interface.lua

local options = require("neotest-golang.options")
local query = require("neotest-golang.query")
local lib = require("neotest-golang.lib")

local M = {}

--- See neotest.Adapter for the full interface.
--- @class Adapter : neotest.Adapter
--- @field name string
M.Adapter = {
  name = "neotest-golang",
  init = function() end,
}

--- Find the project root directory given a current directory to work from.
--- Should no root be found, the adapter can still be used in a non-project context if a test file matches.
--- @async
--- @param dir string @Directory to treat as cwd
--- @return string | nil @Absolute root dir of test suite
function M.Adapter.root(dir)
  -- Since neotest-golang is setting the cwd prior to running tests or debugging
  -- we can use the cwd as-is and treat it as the root.
  return dir
end

--- Filter directories when searching for test files
--- @async
--- @param name string Name of directory
--- @param rel_path string Path to directory, relative to root
--- @param root string Root directory of project
--- @return boolean
function M.Adapter.filter_dir(name, rel_path, root)
  local ignore_dirs = { ".git", "node_modules", ".venv", "venv" }
  for _, ignore in ipairs(ignore_dirs) do
    if name == ignore then
      return false
    end
  end
  return true
end

--- @async
--- @param file_path string
--- @return boolean
function M.Adapter.is_test_file(file_path)
  return vim.endswith(file_path, "_test.go")
end

--- Given a file path, parse all the tests within it.
--- @async
--- @param file_path string Absolute file path
--- @return neotest.Tree | nil
function M.Adapter.discover_positions(file_path)
  return query.detect_tests(file_path)
end

--- Build the runspec, which describes what command(s) are to be executed.
--- @param args neotest.RunArgs
--- @return neotest.RunSpec | neotest.RunSpec[] | nil
function M.Adapter.build_spec(args)
  local runner = lib.cmd.runner_fallback(options.get().runner)
  return options.get().runners[runner].build_spec(args)
end

--- Process the test command output and result. Populate test outcome into the
--- Neotest internal tree structure.
--- @async
--- @param spec neotest.RunSpec
--- @param result neotest.StrategyResult
--- @param tree neotest.Tree
--- @return table<string, neotest.Result> | nil
function M.Adapter.results(spec, result, tree)
  local runner = lib.cmd.runner_fallback(options.get().runner)
  return options.get().runners[runner].results(spec, result, tree)
end

--- Adapter options.
setmetatable(M.Adapter, {
  __call = function(_, opts)
    M.Adapter.options = options.setup(opts)
    return M.Adapter
  end,
})

return M.Adapter
