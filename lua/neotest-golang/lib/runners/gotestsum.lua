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

  -- Return execution context containing the JSON file path
  local exec_context = { json_filepath = json_filepath }
  return cmd, exec_context
end

function GotestsumRunner:process_output(result, exec_context)
  if not exec_context or not exec_context.json_filepath then
    logger.error("Gotestsum execution context missing JSON filepath")
    return {}
  end

  local file_stat = vim.uv.fs_stat(exec_context.json_filepath)
  if not file_stat or file_stat.size == 0 then
    logger.error("Gotestsum JSON output file is missing or empty")
    return {}
  end

  return async.fn.readfile(exec_context.json_filepath)
end

function GotestsumRunner:is_available()
  return vim.fn.executable("gotestsum") == 1
end

--- Get streaming strategy for gotestsum runner
--- @param exec_context table|nil Execution context containing json_filepath
--- @return StreamingStrategy Strategy object configured for file streaming
function GotestsumRunner:get_streaming_strategy(exec_context)
  if not exec_context or not exec_context.json_filepath then
    logger.error("JSON filepath is required for gotestsum runner streaming")
    -- Return error strategy that indicates the condition
    return {
      source = "file",
      get_data = function()
        logger.warn("Streaming disabled: JSON filepath missing")
        return {}
      end,
      stop = function()
        logger.debug("Stream stop called but streaming was disabled")
      end,
    }
  end

  -- Use file-based streaming strategy with mode detection
  local stream = require("neotest-golang.lib.stream")
  local file_strategy =
    require("neotest-golang.lib.stream_strategy.file_stream")

  -- Determine if we're in test mode based on global override
  local test_mode = stream._test_stream_strategy ~= nil

  local data_function, stop_function =
    file_strategy.create_stream(exec_context.json_filepath, test_mode)

  return {
    source = "file",
    get_data = data_function,
    stop = stop_function,
  }
end

return GotestsumRunner
