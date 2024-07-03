--- Helpers to build the command and context around running a single test.

local async = require("neotest.async")

local convert = require("neotest-golang.convert")
local options = require("neotest-golang.options")
local json = require("neotest-golang.json")
local cmd = require("neotest-golang.cmd")

local M = {}

--- Build runspec for a single test
--- @param pos neotest.Position
--- @param strategy string
--- @return neotest.RunSpec | neotest.RunSpec[] | nil
function M.build(pos, strategy)
  --- @type string
  local test_folder_absolute_path = string.match(pos.path, "(.+)/")
  local go_list_command = cmd.build_golist_cmd(test_folder_absolute_path)
  local golist_output = json.process_golist_output(go_list_command)

  --- @type string
  local test_name = convert.to_gotest_test_name(pos.id)
  test_name = convert.to_gotest_regex_pattern(test_name)

  --- The runner to use for running tests.
  --- @type string
  local runner = options.get().runner

  -- TODO: if gotestsum, check if it is on $PATH, or fall back onto `go test`

  --- The filepath to write test output JSON to, if using `gotestsum`.
  --- @type string | nil
  local json_filepath = nil

  --- The final test command to execute.
  --- @type table<string>
  local test_cmd = {}

  if runner == "go" then
    test_cmd =
      cmd.build_gotest_cmd_for_test(test_folder_absolute_path, test_name)
  elseif runner == "gotestsum" then
    json_filepath = vim.fs.normalize(async.fn.tempname())
    test_cmd = cmd.build_gotestsum_cmd_for_test(
      test_folder_absolute_path,
      test_name,
      json_filepath
    )
  end

  return M.build_runspec(
    pos,
    test_folder_absolute_path,
    test_cmd,
    golist_output,
    json_filepath,
    strategy,
    test_name
  )
end

--- Build runspec for a directory of tests
--- @param pos neotest.Position
--- @param cwd string
--- @param test_cmd table<string>
--- @param golist_output table
--- @param json_filepath string | nil
--- @param strategy string
--- @param test_name string
--- @return neotest.RunSpec | neotest.RunSpec[] | nil
function M.build_runspec(
  pos,
  cwd,
  test_cmd,
  golist_output,
  json_filepath,
  strategy,
  test_name
)
  --- @type neotest.RunSpec
  local run_spec = {
    command = test_cmd,
    cwd = cwd,
    context = {
      id = pos.id,
      test_filepath = pos.path,
      golist_output = golist_output,
      pos_type = "test",
    },
  }

  if json_filepath ~= nil then
    run_spec.context.jsonfile = json_filepath
  end

  -- set up for debugging of test
  if strategy == "dap" then
    run_spec.strategy = M.get_dap_config(test_name)
    run_spec.context.skip = true -- do not attempt to parse test output

    -- nvim-dap and nvim-dap-go cwd
    if options.get().dap_go_enabled then
      local dap_go_opts = options.get().dap_go_opts or {}
      local dap_go_opts_original = vim.deepcopy(dap_go_opts)
      if dap_go_opts.delve == nil then
        dap_go_opts.delve = {}
      end
      dap_go_opts.delve.cwd = cwd
      require("dap-go").setup(dap_go_opts)

      -- reset nvim-dap-go (and cwd) after debugging with nvim-dap
      require("dap").listeners.after.event_terminated["neotest-golang-debug"] = function()
        require("dap-go").setup(dap_go_opts_original)
      end
    end
  end

  return run_spec
end

--- @param test_name string
--- @return table | nil
function M.get_dap_config(test_name)
  -- :help dap-configuration
  local dap_config = {
    type = "go",
    name = "Neotest-golang",
    request = "launch",
    mode = "test",
    program = "${fileDirname}",
    args = { "-test.run", "^" .. test_name .. "$" },
  }

  return dap_config
end

return M
