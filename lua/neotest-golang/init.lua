--- This is the main entry point for the neotest-golang adapter. It follows the
--- Neotest interface: https://github.com/nvim-neotest/neotest/blob/master/lua/neotest/adapters/interface.lua

local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")
local query = require("neotest-golang.query")
local runspec = require("neotest-golang.runspec")
local process = require("neotest-golang.process")

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
  --- The tree object, describing the AST-detected tests and their positions.
  --- @type neotest.Tree
  local tree = args.tree

  --- The position object, describing the current directory, file or test.
  --- @type neotest.Position
  local pos = args.tree:data() -- NOTE: causes <file> is not accessible by the current user!

  if not tree then
    logger.error("Unexpectedly did not receive a neotest.Tree.")
    return
  end

  -- Below is the main logic of figuring out how to execute tests. In short,
  -- a "runspec" is defined for each command to execute.
  -- Neotest also distinguishes between different "position types":
  -- - "dir": A directory of tests
  -- - "file": A single test file
  -- - "namespace": A set of tests, collected under the same namespace
  -- - "test": A single test
  --
  -- If a valid runspec is built and returned from this function, it will be
  -- executed by Neotest. But if, for some reason, this function returns nil,
  -- Neotest will call this function again, but using the next position type
  -- (in this order: dir, file, namespace, test). This gives the ability to
  -- have fallbacks.
  -- For example, if a runspec cannot be built for a file of tests, we can
  -- instead try to build a runspec for each individual test file. The end
  -- result would in this case produce multiple commands to execute (for each
  -- test) rather than one command for the file.
  -- The idea here is not to have such fallbacks take place in the future, but
  -- while this adapter is being developed, it can be useful to have such
  -- functionality.

  if pos.type == "dir" and pos.path == vim.fn.getcwd() then
    -- A runspec is to be created, based on running all tests in the given
    -- directory. In this case, the directory is also the current working
    -- directory.
    return runspec.dir.build(pos)
  elseif pos.type == "dir" then
    -- A runspec is to be created, based on running all tests in the given
    -- directory. In this case, the directory is a sub-directory of the current
    -- working directory.
    return runspec.dir.build(pos)
  elseif pos.type == "file" then
    -- A runspec is to be created, based on on running all tests in the given
    -- file.
    return runspec.file.build(pos, tree, args.strategy)
  elseif pos.type == "namespace" then
    -- A runspec is to be created, based on running all tests in the given
    -- namespace.
    return runspec.namespace.build(pos)
  elseif pos.type == "test" then
    -- A runspec is to be created, based on on running the given test.
    return runspec.test.build(pos, args.strategy)
  end

  logger.error(
    "Unknown Neotest position type, "
      .. "cannot build runspec with position type: "
      .. pos.type
  )
end

--- Process the test command output and result. Populate test outcome into the
--- Neotest internal tree structure.
--- @async
--- @param spec neotest.RunSpec
--- @param result neotest.StrategyResult
--- @param tree neotest.Tree
--- @return table<string, neotest.Result> | nil
function M.Adapter.results(spec, result, tree)
  local pos = tree:data()

  if pos.type == "dir" then
    -- A test command executed a directory of tests and the output/status must
    -- now be processed.
    local results = process.test_results(spec, result, tree)
    M.workaround_neotest_issue_391(result)
    return results
  elseif pos.type == "file" then
    -- A test command executed a file of tests and the output/status must
    -- now be processed.
    local results = process.test_results(spec, result, tree)
    M.workaround_neotest_issue_391(result)
    return results
  elseif pos.type == "namespace" then
    -- A test command executed a namespace and the output/status must now be
    -- processed.
    local results = process.test_results(spec, result, tree)
    M.workaround_neotest_issue_391(result)
    return results
  elseif pos.type == "test" then
    -- A test command executed a single test and the output/status must now be
    -- processed.
    local results = process.test_results(spec, result, tree)
    M.workaround_neotest_issue_391(result)
    return results
  end

  logger.error(
    "Cannot process test results due to unknown Neotest position type:"
      .. pos.type
  )
end

--- Workaround, to avoid JSON in output panel, erase contents of output.
--- @param result neotest.StrategyResult
function M.workaround_neotest_issue_391(result)
  -- FIXME: once output is processed, erase file contents, so to avoid JSON in
  -- output panel. This is a workaround for now, only because of
  -- https://github.com/nvim-neotest/neotest/issues/391

  -- NOTE: when emptying the file with vim.fn.writefil, this error was hit
  -- when debugging:
  -- E5560: Vimscript function must not be called in a lua loop callback
  -- vim.fn.writefile({ "" }, result.output)

  if result.output ~= nil then -- and vim.fn.filereadable(result.output) == 1 then
    local file = io.open(result.output, "w")
    if file ~= nil then
      file:write("")
      file:close()
    end
  end
end

--- Adapter options.
setmetatable(M.Adapter, {
  __call = function(_, opts)
    M.Adapter.options = options.setup(opts)
    return M.Adapter
  end,
})

return M.Adapter
