--- Helper functions building the command to execute.

local async = require("neotest.async")

local options = require("neotest-golang.options")
local json = require("neotest-golang.json")

local M = {}

function M.golist_data(cwd)
  -- call 'go list -json ./...' to get test file data
  local go_list_command = {
    "go",
    "list",
    "-json",
    "./...",
  }
  local output =
    vim.fn.system("cd " .. cwd .. " && " .. table.concat(go_list_command, " "))
  return json.process_golist_output(output)
end

function M.test_command_for_individual_test(
  test_folder_absolute_path,
  test_name
)
  local go_test_required_args = { test_folder_absolute_path, "-run", test_name }
  local cmd, json_filepath = M.test_command(go_test_required_args)
  return cmd, json_filepath
end

function M.test_command_for_dir(module_name)
  local go_test_required_args = { module_name }
  local cmd, json_filepath = M.test_command(go_test_required_args)
  return cmd, json_filepath
end

function M.test_command(go_test_required_args)
  --- The runner to use for running tests.
  --- @type string
  local runner = M.fallback_to_go_test(options.get().runner)

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

function M.fallback_to_go_test(executable)
  if vim.fn.executable(executable) == 0 then
    vim.notify(
      "Runner " .. executable .. " not found. Falling back to 'go'.",
      vim.log.levels.WARN
    )
    options.set({ runner = "go" })
    return options.get().runner
  end
  return options.get().runner
end

return M
