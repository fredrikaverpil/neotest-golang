--- Test runner strategies for different Go test execution backends.
--- Implements the Strategy pattern to encapsulate runner-specific logic.

local logger = require("neotest-golang.logging")

local M = {}

--- Base runner interface that all concrete runners must implement
--- @class RunnerInterface
--- @field name string The name of the runner
local RunnerInterface = {}

--- Build test command for the given arguments
--- @param go_test_required_args string[] Required arguments for the test command
--- @param fallback boolean Whether to use fallback logic
--- @return string[], string|nil Command array and optional JSON output path
function RunnerInterface:get_test_command(go_test_required_args, fallback)
  error("get_test_command must be implemented by concrete runner")
end

--- Process test output and return lines for parsing
--- @param output_file string|nil Path to output file
--- @param context table|nil Additional context (e.g., JSON file path)
--- @return string[] Output lines for processing
function RunnerInterface:process_output(output_file, context)
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

M.RunnerInterface = RunnerInterface

--- Factory function to create runner instances
--- @param runner_name string Name of the runner ("go" or "gotestsum")
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

