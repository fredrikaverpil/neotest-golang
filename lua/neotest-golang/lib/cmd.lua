--- Helper functions building the command to execute.

local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")
local json = require("neotest-golang.lib.json")

local M = {}

--- Call 'go list -json {go_list_args...} ./...' to get test file data
--- @param cwd string
function M.golist_data(cwd)
  local cmd = M.golist_command()
  local go_list_command_concat = table.concat(cmd, " ")
  logger.debug("Running Go list: " .. go_list_command_concat .. " in " .. cwd)
  local result = vim.system(cmd, { cwd = cwd, text = true }):wait()

  local err = nil
  if result.code == 1 then
    err = "go list:"
    if result.stdout ~= nil and result.stdout ~= "" then
      err = err .. " " .. result.stdout
    end
    if result.stdout ~= nil and result.stderr ~= "" then
      err = err .. " " .. result.stderr
    end
    logger.debug({ "Go list error: ", err })
  end

  local output = result.stdout or ""

  local golist_output = json.decode_from_string(output)
  logger.debug({ "JSON-decoded 'go list' output: ", golist_output })
  return golist_output, err
end

function M.golist_command()
  local cmd = { "go", "list", "-json" }
  local go_list_args = options.get().go_list_args
  if type(go_list_args) == "function" then
    go_list_args = go_list_args()
  end
  vim.list_extend(cmd, go_list_args or {})
  vim.list_extend(cmd, { "./..." })
  return cmd
end

--- @class TestCommandData
--- @field package_name string | nil The Go package name.
--- @field position neotest.Position The position of the test.
--- @field regexp string | nil The regular expression to filter tests.

--- Generate the test command to execute.
--- @param cmd_data TestCommandData
--- @return table<string>, string | nil
function M.test_command(cmd_data)
  --- The runner to use for running tests.
  --- @type string
  local runner = M.runner_fallback(options.get().runner)

  --- Optional and custom filepath for writing test output.
  --- @type string | nil
  local test_output_filepath = nil

  --- The final test command to execute.
  --- @type table<string>
  local cmd = {}

  cmd, test_output_filepath = options.get().runners[runner].cmd(cmd_data)
  logger.info("Test command: " .. table.concat(cmd, " "))

  return cmd, test_output_filepath
end

function M.runner_fallback(executable)
  if M.system_has(executable) == false then
    logger.warn(
      "Runner not found: " .. executable .. ". Will fall back to 'go'."
    )
    options.set({ runner = "go" })
    return options.get().runner
  end
  return options.get().runner
end

function M.system_has(executable)
  if vim.fn.executable(executable) == 0 then
    logger.warn("Executable not found: " .. executable)
    return false
  end
  return true
end

return M
