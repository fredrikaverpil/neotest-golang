--- Test runner strategies for different Go test execution backends.
--- Implements the Strategy pattern to encapsulate runner-specific logic.

local logger = require("neotest-golang.logging")

local M = {}

--- Execution context data structure for runner-specific information
--- @class RunnerExecContext
--- @field json_filepath? string Path to JSON output file (gotestsum specific)

--- Base runner interface that all concrete runners must implement
--- @class RunnerInterface
--- @field name string The name of the runner
local RunnerInterface = {}

--- Build test command for the given arguments
--- @param go_test_required_args string[] Required arguments for the test command
--- @param fallback boolean Whether to use fallback logic
--- @return string[] command Command array to execute
--- @return RunnerExecContext|nil exec_context Execution context (opaque to callers)
function RunnerInterface:get_test_command(go_test_required_args, fallback)
  error("get_test_command must be implemented by concrete runner")
end

--- Process test output and return lines for parsing
--- @param result neotest.StrategyResult The strategy result containing output and other execution data
--- @param exec_context RunnerExecContext|nil Execution context returned from get_test_command
--- @return string[] Output lines for processing
function RunnerInterface:process_output(result, exec_context)
  error("process_output must be implemented by concrete runner")
end

--- Check if this runner is available on the system
--- @return boolean True if runner is available
function RunnerInterface:is_available()
  error("is_available must be implemented by concrete runner")
end

--- Get fallback runner name if this runner is not available
--- @return string Fallback runner name
function RunnerInterface:get_fallback()
  return "go"
end

--- Get streaming strategy for this runner
--- @param exec_context RunnerExecContext|nil Execution context from get_test_command
--- @return StreamingStrategy Strategy object with source metadata and stream functions
function RunnerInterface:get_streaming_strategy(exec_context)
  error("get_streaming_strategy must be implemented by concrete runner")
end

M.RunnerInterface = RunnerInterface

--- Factory function to create runner instances
--- @param runner_name "go"|"gotestsum" Name of the runner
--- @param fallback boolean Whether to use fallback logic
--- @return RunnerInterface The runner instance
function M.create_runner(runner_name, fallback)
  local runner

  if runner_name == "go" then
    local GoRunner = require("neotest-golang.lib.runners.go")
    runner = GoRunner:new()
  elseif runner_name == "gotestsum" then
    local GotestsumRunner = require("neotest-golang.lib.runners.gotestsum")
    runner = GotestsumRunner:new()
  else
    error("Unknown runner: " .. runner_name)
  end

  if fallback and not runner:is_available() then
    local fallback_name = runner:get_fallback()
    logger.warn(
      "Runner '"
        .. runner_name
        .. "' not available, falling back to '"
        .. fallback_name
        .. "'",
      true
    )
    return M.create_runner(fallback_name, false)
  end

  return runner
end

return M
