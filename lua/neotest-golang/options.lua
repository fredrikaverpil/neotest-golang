--- These are the default options for neotest-golang. You can override them by
--- providing them as arguments to the Adapter function. See the README for mode
--- details and examples.

local logger = require("neotest-golang.logging")
local async = require("neotest.async")

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

local default_runners = {
  runners = {
    go = {
      cmd = function(cmd_data)
        local cmd = { "go", "test", "-json" }
        local go_test_args = defaults.go_test_args
        if type(go_test_args) == "function" then
          go_test_args = go_test_args()
        end
        local required_go_test_args = {}
        if cmd_data.regexp ~= nil then
          required_go_test_args =
            { cmd_data.package_or_path, "-run", cmd_data.regexp }
        else
          required_go_test_args = { cmd_data.package_or_path }
        end
        cmd = vim.list_extend(vim.deepcopy(cmd), go_test_args)
        cmd = vim.list_extend(vim.deepcopy(cmd), required_go_test_args)
        return cmd, nil
      end,
    },
    gotestsum = {
      cmd = function(cmd_data)
        local json_filepath = vim.fs.normalize(async.fn.tempname())
        local cmd = { "gotestsum", "--jsonfile=" .. json_filepath }
        local gotestsum_args = defaults.gotestsum_args
        if type(gotestsum_args) == "function" then
          gotestsum_args = gotestsum_args()
        end
        local go_test_args = defaults.go_test_args
        if type(go_test_args) == "function" then
          go_test_args = go_test_args()
        end
        local required_go_test_args = {}
        if cmd_data.regexp ~= nil then
          required_go_test_args =
            { cmd_data.package_or_path, "-run", cmd_data.regexp }
        else
          required_go_test_args = { cmd_data.package_or_path }
        end
        cmd = vim.list_extend(vim.deepcopy(cmd), gotestsum_args)
        cmd = vim.list_extend(vim.deepcopy(cmd), { "--" })
        cmd = vim.list_extend(vim.deepcopy(cmd), go_test_args)
        cmd = vim.list_extend(vim.deepcopy(cmd), required_go_test_args)
        return cmd, json_filepath
      end,
    },
  },
}

local opts = vim.tbl_extend("force", defaults, default_runners)

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
