--- Gotestsum runner implementation with enhanced output formatting.
--- Gotestsum is a third-party tool that wraps 'go test' and provides better output formatting,
--- faster test execution, and additional features like test result caching.
--- Learn more: https://github.com/gotestyourself/gotestsum

local async = require("neotest.async")
local logger = require("neotest-golang.logging")

--- Gotestsum runner implementation
--- @class GotestsumRunner : RunnerInterface
local GotestsumRunner = {}
GotestsumRunner.name = "gotestsum"

--- Create a new instance of the GotestsumRunner
--- Uses Lua metatables to implement inheritance-like behavior:
--- - Creates a new empty table (instance)
--- - Sets GotestsumRunner as the metatable with __index pointing to self
--- - This allows the instance to "inherit" all methods from GotestsumRunner
--- @return GotestsumRunner New instance with access to all GotestsumRunner methods
function GotestsumRunner:new()
  local instance = setmetatable({}, { __index = self })
  return instance
end

function GotestsumRunner:get_test_command(go_test_required_args, fallback)
  local extra_args = require("neotest-golang.extra_args")
  local options = require("neotest-golang.options")

  local json_filepath = vim.fs.normalize(async.fn.tempname())
  local cmd = { "gotestsum", "--jsonfile=" .. json_filepath }

  local gotestsum_args = options.get().gotestsum_args
  if type(gotestsum_args) == "function" then
    gotestsum_args = gotestsum_args()
  end

  local go_test_args = extra_args.get().go_test_args
    or options.get().go_test_args
  if type(go_test_args) == "function" then
    go_test_args = go_test_args()
  end

  cmd = vim.list_extend(vim.deepcopy(cmd), gotestsum_args)
  cmd = vim.list_extend(vim.deepcopy(cmd), { "--" })
  cmd = vim.list_extend(vim.deepcopy(cmd), go_test_required_args)
  cmd = vim.list_extend(vim.deepcopy(cmd), go_test_args)

  return cmd, json_filepath
end

function GotestsumRunner:process_output(output_file, context)
  if not context or not context.test_output_json_filepath then
    logger.error("Gotestsum JSON output file path not provided")
    return {}
  end

  local file_stat = vim.uv.fs_stat(context.test_output_json_filepath)
  if not file_stat or file_stat.size == 0 then
    logger.error("Gotestsum JSON output file is missing or empty")
    return {}
  end

  return async.fn.readfile(context.test_output_json_filepath)
end

function GotestsumRunner:is_available()
  return vim.fn.executable("gotestsum") == 1
end

return GotestsumRunner

