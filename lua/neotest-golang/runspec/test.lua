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
  local pos_path_folderpath = vim.fn.fnamemodify(pos.path, ":h")

  local golist_data, golist_error = lib.cmd.golist_data(pos_path_folderpath)

  local errors = nil
  if golist_error ~= nil then
    if errors == nil then
      errors = {}
    end
    table.insert(errors, golist_error)
  end

  local test_name = lib.convert.to_gotest_test_name(pos.id)
  local test_name_regex = lib.convert.to_gotest_regex_pattern(test_name)

  local test_cmd, json_filepath = lib.cmd.test_command_in_package_with_regexp(
    pos_path_folderpath,
    test_name_regex
  )

  local runspec_strategy = nil
  if strategy == "dap" then
    dap.assert_dap_prerequisites()
    runspec_strategy = dap.get_dap_config(pos_path_folderpath, test_name_regex)
    logger.debug("DAP strategy used: " .. vim.inspect(runspec_strategy))
    dap.setup_debugging(pos_path_folderpath)
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
    cwd = pos_path_folderpath,
    context = context,
  }

  if runspec_strategy ~= nil then
    run_spec.strategy = runspec_strategy
    run_spec.context.is_dap_active = true
  end

  logger.debug({ "RunSpec:", run_spec })
  return run_spec
end

return M
