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

  return cmd, nil
end

function GoRunner:process_output(output_file, context)
  if not output_file then
    logger.error("Go test output file is missing")
    return {}
  end
  if vim.fn.filereadable(output_file) ~= 1 then
    logger.error("Go test output file is not readable: " .. output_file)
    return {}
  end
  return async.fn.readfile(output_file)
end

function GoRunner:is_available()
  return vim.fn.executable("go") == 1
end

return GoRunner
