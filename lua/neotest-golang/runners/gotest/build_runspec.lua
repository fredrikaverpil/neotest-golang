local logger = require("neotest-golang.logging")

local M = {}

--- Build the runspec, which describes what command(s) are to be executed.
--- @param args neotest.RunArgs
--- @return neotest.RunSpec | neotest.RunSpec[] | nil
function M.build_gotest_spec(args)
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

  local runspec = require("neotest-golang.runners.gotest.runspec")

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

return M
