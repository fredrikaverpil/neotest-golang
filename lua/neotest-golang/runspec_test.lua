local convert = require("neotest-golang.convert")
local options = require("neotest-golang.options")

local M = {}

--- Build runspec for a single test
--- @param pos neotest.Position
--- @param strategy string
--- @return neotest.RunSpec | neotest.RunSpec[] | nil
function M.build(pos, strategy)
  --- @type string
  local test_name = convert.to_gotest_test_name(pos.id)
  test_name = convert.to_gotest_regex_pattern(test_name)

  --- @type string
  local test_folder_absolute_path = string.match(pos.path, "(.+)/")

  local gotest = {
    "go",
    "test",
    "-json",
  }

  --- @type table
  local required_go_test_args = { test_folder_absolute_path, "-run", test_name }

  local combined_args = vim.list_extend(
    vim.deepcopy(options.get().go_test_args),
    required_go_test_args
  )
  local gotest_command = vim.list_extend(vim.deepcopy(gotest), combined_args)

  --- @type neotest.RunSpec
  local run_spec = {
    command = gotest_command,
    cwd = test_folder_absolute_path,
    context = {
      id = pos.id,
      test_filepath = pos.path,
      pos_type = "test",
    },
  }

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
      dap_go_opts.delve.cwd = test_folder_absolute_path
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
