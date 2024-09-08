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

  local errors = {}
  if golist_error ~= nil then
    table.insert(errors, golist_error)
  end

  local test_name = lib.convert.to_gotest_test_name(pos.id)
  local test_name_regex = lib.convert.to_gotest_regex_pattern(test_name)

  local test_cmd, json_filepath = lib.cmd.test_command_in_package_with_regexp(
    test_folder_absolute_path,
    test_name_regex
  )

  local runspec_strategy = nil
  if strategy == "dap" then
    M.assert_dap_prerequisites()
    runspec_strategy = dap.get_dap_config(test_name_regex)
    logger.debug("DAP strategy used: " .. vim.inspect(runspec_strategy))
    dap.setup_debugging(test_folder_absolute_path)
  end

  --- @type RunspecContext
  local context = {
    pos_id = pos.id,
    golist_data = golist_data,
    errors = errors,
    parse_test_results = true,
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
    run_spec.context.parse_test_results = false
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
