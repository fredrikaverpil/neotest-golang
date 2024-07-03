--- Helper functions building the command to execute.

local options = require("neotest-golang.options")

local M = {}

function M.build_golist_cmd(cwd)
  -- call 'go list -json ./...' to get test file data
  local go_list_command = {
    "go",
    "list",
    "-json",
    "./...",
  }
  local go_list_command_result =
    vim.fn.system("cd " .. cwd .. " && " .. table.concat(go_list_command, " "))
  return go_list_command_result
end

function M.build_gotest_cmd_for_dir(module_name)
  local gotest = {
    "go",
    "test",
    "-json",
  }

  local required_go_test_args = {
    module_name,
  }

  local combined_args = vim.list_extend(
    vim.deepcopy(options.get().go_test_args),
    required_go_test_args
  )
  local cmd = vim.list_extend(vim.deepcopy(gotest), combined_args)

  return cmd
end

function M.build_gotestsum_cmd_for_dir(module_name, json_filepath)
  local gotest = { "gotestsum" }
  local gotestsum_json = {
    "--jsonfile=" .. json_filepath,
    "--",
  }

  local required_go_test_args = {
    module_name,
  }

  local gotest_args = vim.list_extend(
    vim.deepcopy(options.get().go_test_args),
    required_go_test_args
  )

  local cmd =
    vim.list_extend(vim.deepcopy(gotest), options.get().gotestsum_args)
  cmd = vim.list_extend(vim.deepcopy(cmd), gotestsum_json)
  cmd = vim.list_extend(vim.deepcopy(cmd), gotest_args)

  return cmd
end

function M.build_gotest_cmd_for_test(test_folder_absolute_path, test_name)
  --- @type table
  local required_go_test_args = { test_folder_absolute_path, "-run", test_name }

  local gotest = {
    "go",
    "test",
    "-json",
  }

  local combined_args = vim.list_extend(
    vim.deepcopy(options.get().go_test_args),
    required_go_test_args
  )
  local cmd = vim.list_extend(vim.deepcopy(gotest), combined_args)
  return cmd
end

function M.build_gotestsum_cmd_for_test(
  test_folder_absolute_path,
  test_name,
  json_filepath
)
  --- @type table
  local required_go_test_args = { test_folder_absolute_path, "-run", test_name }

  local gotest = { "gotestsum" }
  local gotestsum_json = {
    "--jsonfile=" .. json_filepath,
    "--",
  }

  local gotest_args = vim.list_extend(
    vim.deepcopy(options.get().go_test_args),
    required_go_test_args
  )

  local cmd =
    vim.list_extend(vim.deepcopy(gotest), options.get().gotestsum_args)
  cmd = vim.list_extend(vim.deepcopy(cmd), gotestsum_json)
  cmd = vim.list_extend(vim.deepcopy(cmd), gotest_args)

  return cmd
end

return M
