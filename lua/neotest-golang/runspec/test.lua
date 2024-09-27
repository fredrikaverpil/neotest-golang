--- Helpers to build the command and context around running a single test.

local logger = require("neotest-golang.logging")
local lib = require("neotest-golang.lib")
local dap = require("neotest-golang.features.dap")

local M = {}

--- Build runspec for a single test
--- @param pos neotest.Position
--- @param strategy string
--- @return neotest.RunSpec | neotest.RunSpec[] | nil
function M.build(pos, strategy)
  local test_folder_absolute_path =
    string.match(pos.path, "(.+)" .. lib.find.os_path_sep)

  local golist_data, golist_error =
    lib.cmd.golist_data(test_folder_absolute_path)

  local errors = nil
  if golist_error ~= nil then
    if errors == nil then
      errors = {}
    end
    table.insert(errors, golist_error)
  end

  local test_name = lib.convert.to_gotest_test_name(pos.id)
  local test_name_regexp = lib.convert.to_gotest_regex_pattern(test_name)

  -- find the go package that corresponds to the pos.path
  local package_name = "./..."
  local pos_path_filename = vim.fn.fnamemodify(pos.path, ":t")
  local pos_path_foldername = vim.fn.fnamemodify(pos.path, ":h")
  for _, golist_item in ipairs(golist_data) do
    if golist_item.TestGoFiles ~= nil then
      if
        pos_path_foldername == golist_item.Dir
        and vim.tbl_contains(golist_item.TestGoFiles, pos_path_filename)
      then
        package_name = golist_item.ImportPath
        break
      end
    end
  end

  local cmd_data = {
    package_name = package_name,
    position = pos,
    regexp = test_name_regexp,
  }
  local test_cmd, json_filepath = lib.cmd.test_command(cmd_data)

  local runspec_strategy = nil
  if strategy == "dap" then
    M.assert_dap_prerequisites()
    runspec_strategy = dap.get_dap_config(test_name_regexp)
    logger.debug("DAP strategy used: " .. vim.inspect(runspec_strategy))
    dap.setup_debugging(test_folder_absolute_path)
  end

  --- @type RunspecContext
  local context = {
    pos_id = pos.id,
    golist_data = golist_data,
    errors = errors,
    process_test_results = true,
    test_output_json_filepath = json_filepath,
  }

  --- @type neotest.RunSpec
  local run_spec = {
    command = test_cmd,
    cwd = test_folder_absolute_path,
    context = context,
  }

  if runspec_strategy ~= nil then
    run_spec.strategy = runspec_strategy
    run_spec.context.is_dap_active = true
  end

  logger.debug({ "RunSpec:", run_spec })
  return run_spec
end

function M.assert_dap_prerequisites()
  local dap_go_found = pcall(require, "dap-go")
  if not dap_go_found then
    local msg = "You must have leoluz/nvim-dap-go installed to use DAP strategy. "
      .. "See the neotest-golang README for more information."
    logger.error(msg)
    error(msg)
  end
end

return M
