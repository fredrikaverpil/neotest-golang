--- Go test runner implementation using the standard 'go test -json' command.

local async = require("neotest.async")
local logger = require("neotest-golang.logging")

--- Go test runner implementation
--- @class GoRunner : RunnerInterface
--- @field name string
local GoRunner = {}
GoRunner.name = "go"

--- Create a new instance of the GoRunner
--- Uses Lua metatables to implement inheritance-like behavior:
--- - Creates a new empty table (instance)
--- - Sets GoRunner as the metatable with __index pointing to self
--- - This allows the instance to "inherit" all methods from GoRunner
--- @return GoRunner New instance with access to all GoRunner methods
function GoRunner:new()
  local instance = setmetatable({}, { __index = self })
  return instance
end

--- Build test command for the given arguments
--- @param go_test_required_args string[] Required arguments for the test command
--- @param fallback boolean Whether to use fallback logic (unused for go runner)
--- @return string[] command Command array to execute
--- @return GoExecContext exec_context Execution context for go runner
function GoRunner:get_test_command(go_test_required_args, fallback)
  local extra_args = require("neotest-golang.extra_args")
  local options = require("neotest-golang.options")

  local cmd = { "go", "test", "-json" }
  local args = extra_args.get().go_test_args or options.get().go_test_args
  if type(args) == "function" then
    args = args()
  end

  cmd = vim.list_extend(vim.deepcopy(cmd), go_test_required_args)
  cmd = vim.list_extend(vim.deepcopy(cmd), args)

  -- GoRunner returns typed execution context for consistency with interface
  return cmd, { type = "go" }
end

--- Process test output and return lines for parsing
--- @param result neotest.StrategyResult The strategy result containing output and other execution data
--- @param exec_context GoExecContext Execution context (not used by go runner)
--- @return string[] Output lines for processing
function GoRunner:process_output(result, exec_context)
  if not result.output then
    logger.error("Go test output file is missing")
    return {}
  end
  if vim.fn.filereadable(result.output) ~= 1 then
    logger.error("Go test output file is not readable: " .. result.output)
    return {}
  end
  return async.fn.readfile(result.output)
end

--- Check if this runner is available on the system
--- @return boolean True if go executable is available
function GoRunner:is_available()
  return vim.fn.executable("go") == 1
end

--- Get streaming strategy for go test runner
--- @param exec_context GoExecContext Execution context (unused for go runner)
--- @return StreamingStrategy Strategy object configured for stdout streaming
function GoRunner:get_streaming_strategy(exec_context)
  -- Go runner uses stdout-based streaming from neotest's data() function
  local stdout_strategy =
    require("neotest-golang.lib.stream_strategy.stdout_stream")
  local data_function, stop_function =
    stdout_strategy.create_stream(exec_context)

  return {
    source = "stdout",
    get_data = data_function,
    stop = stop_function,
  }
end

return GoRunner
