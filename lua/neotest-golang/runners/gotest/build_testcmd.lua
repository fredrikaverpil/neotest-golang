local M = {}

function M.test_command_builder(cmd_data, defaults)
  local cmd = { "go", "test", "-json" }
  local go_test_args = defaults.go_test_args
  if type(go_test_args) == "function" then
    go_test_args = go_test_args()
  end
  local required_go_test_args = {}
  if
    cmd_data.position.type == "test"
    or cmd_data.position.type == "namespace"
  then
    local absolute_folder_path =
      vim.fn.fnamemodify(cmd_data.position.path, ":h")
    required_go_test_args = { absolute_folder_path, "-run", cmd_data.regexp }
  elseif cmd_data.position.type == "file" then
    if cmd_data.regexp ~= nil then
      required_go_test_args = { cmd_data.package_name, "-run", cmd_data.regexp }
    else
      required_go_test_args = { cmd_data.package_name }
    end
  elseif cmd_data.position.type == "dir" then
    required_go_test_args = { cmd_data.package_name }
  end
  cmd = vim.list_extend(vim.deepcopy(cmd), go_test_args)
  cmd = vim.list_extend(vim.deepcopy(cmd), required_go_test_args)
  return cmd, nil
end

return M
