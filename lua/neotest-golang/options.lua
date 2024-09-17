--- These are the default options for neotest-golang. You can override them by
--- providing them as arguments to the Adapter function. See the README for mode
--- details and examples.

local logger = require("neotest-golang.logging")

local M = {}

local defaults = {
  runner = "go", -- corresponds to a key in the 'runners' table
  go_test_args = { "-v", "-race", "-count=1" }, -- NOTE: can also be a function
  gotestsum_args = { "--format=standard-verbose" }, -- NOTE: can also be a function
  go_list_args = {}, -- NOTE: can also be a function
  dap_go_opts = {}, -- NOTE: can also be a function
  testify_enabled = false,
  warn_test_name_dupes = true,
  warn_test_not_executed = true,

  -- experimental, for now undocumented, options
  dev_notifications = false,
}

local runner_defaults = {
  runners = {
    go = {
      build_spec = function(args)
        local build_runspec =
          require("neotest-golang.runners.gotest.build_runspec")
        return build_runspec.build_gotest_spec(args)
      end,
      ---@param cmd_data TestCommandData
      cmd = function(cmd_data)
        local build_testcmd =
          require("neotest-golang.runners.gotest.build_testcmd")
        return build_testcmd.test_command_builder(cmd_data, defaults)
      end,
      results = function(spec, result, tree)
        local process_output =
          require("neotest-golang.runners.gotest.process_output")
        return process_output.process_gotest_results(spec, result, tree)
      end,
    },
    gotestsum = {
      build_spec = function(args)
        -- gotestsum uses the same logic to build the runspec as the 'go' runner
        local build_runspec =
          require("neotest-golang.runners.gotest.build_runspec")
        return build_runspec.build_gotest_spec(args)
      end,
      ---@param cmd_data TestCommandData
      cmd = function(cmd_data)
        local build_testcmd =
          require("neotest-golang.runners.gotestsum.build_testcmd")
        return build_testcmd.test_command_builder(cmd_data, defaults)
      end,
      results = function(spec, result, tree)
        -- gotestsum uses the same logic to process the results as the 'go' runner
        local process_output =
          require("neotest-golang.runners.gotest.process_output")
        return process_output.process_gotest_results(spec, result, tree)
      end,
    },
  },
}

local opts = vim.tbl_extend("force", defaults, runner_defaults)

function M.setup(user_opts)
  if type(user_opts) == "table" and not vim.tbl_isempty(user_opts) then
    for k, v in pairs(user_opts) do
      opts[k] = v
    end
  else
  end
  logger.debug("Loaded with options: " .. vim.inspect(opts))
end

function M.get()
  return opts
end

function M.set(updated_opts)
  for k, v in pairs(updated_opts) do
    opts[k] = v
  end
  return opts
end

return M
