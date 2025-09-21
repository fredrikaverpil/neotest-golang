--- Go test runner implementation using the standard 'go test -json' command.

local async = require("neotest.async")
local logger = require("neotest-golang.logging")

--- Go test runner implementation
--- @class GoRunner : RunnerInterface
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

  -- GoRunner doesn't need any execution context since it reads from stdout
  return cmd, nil
end

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

function GoRunner:is_available()
  return vim.fn.executable("go") == 1
end

function GoRunner:get_streaming_strategy(exec_context)
  -- Go runner uses stdout-based streaming
  local stdout_strategy =
    require("neotest-golang.lib.stream_strategy.stdout_stream")
  return stdout_strategy.create_stream(exec_context)
end

return GoRunner
