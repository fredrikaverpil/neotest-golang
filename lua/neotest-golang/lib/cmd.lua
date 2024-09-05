--- Helper functions building the command to execute.

local async = require("neotest.async")

local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")
local json = require("neotest-golang.lib.json")

local M = {}

function M.golist_data(cwd)
  -- call 'go list -json {go_list_args...} ./...' to get test file data

  -- combine base command, user args and packages(./...)
  local cmd = { "go", "list", "-json" }
  vim.list_extend(cmd, options.get().go_list_args or {})
  vim.list_extend(cmd, { "./..." })

  local go_list_command_concat = table.concat(cmd, " ")
  logger.debug("Running Go list: " .. go_list_command_concat .. " in " .. cwd)
  local output = vim.system(cmd, { cwd = cwd, text = true }):wait().stdout or ""
  if output == "" then
    logger.error({ "Execution of 'go list' failed, output:", output })
  end
  return json.decode_from_string(output)
end

function M.test_command_in_package(package_or_path)
  local go_test_required_args = { package_or_path }
  local cmd, json_filepath = M.test_command(go_test_required_args)
  return cmd, json_filepath
end

function M.test_command_in_package_with_regexp(package_or_path, regexp)
  local go_test_required_args = { package_or_path, "-run", regexp }
  local cmd, json_filepath = M.test_command(go_test_required_args)
  return cmd, json_filepath
end

function M.test_command(go_test_required_args)
  --- The runner to use for running tests.
  --- @type string
  local runner = M.runner_fallback(options.get().runner)

  --- The filepath to write test output JSON to, if using `gotestsum`.
  --- @type string | nil
  local json_filepath = nil

  --- The final test command to execute.
  --- @type table<string>
  local cmd = {}

  if runner == "go" then
    cmd = M.go_test(go_test_required_args)
  elseif runner == "gotestsum" then
    json_filepath = vim.fs.normalize(async.fn.tempname())
    cmd = M.gotestsum(go_test_required_args, json_filepath)
  end

  logger.info("Test command: " .. table.concat(cmd, " "))

  return cmd, json_filepath
end

function M.go_test(go_test_required_args)
  local cmd = { "go", "test", "-json" }
  cmd = vim.list_extend(vim.deepcopy(cmd), options.get().go_test_args)
  cmd = vim.list_extend(vim.deepcopy(cmd), go_test_required_args)
  return cmd
end

function M.gotestsum(go_test_required_args, json_filepath)
  local cmd = { "gotestsum", "--jsonfile=" .. json_filepath }
  cmd = vim.list_extend(vim.deepcopy(cmd), options.get().gotestsum_args)
  cmd = vim.list_extend(vim.deepcopy(cmd), { "--" })
  cmd = vim.list_extend(vim.deepcopy(cmd), options.get().go_test_args)
  cmd = vim.list_extend(vim.deepcopy(cmd), go_test_required_args)
  return cmd
end

function M.runner_fallback(executable)
  if M.system_has(executable) == false then
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
