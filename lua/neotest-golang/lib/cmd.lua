--- Helper functions building the command to execute.

---@type nio
local async = require("neotest.async")

local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")
local json = require("neotest-golang.lib.json")

local M = {}

--- Call 'go list -json {go_list_args...} ./...' to get test file data
--- @param cwd string
function M.golist_data(cwd)
  local cmd = M.golist_command()
  local go_list_command_concat = table.concat(cmd, " ")
  logger.info("Running Go list: " .. go_list_command_concat .. " in " .. cwd)
  local result = vim.system(cmd, { cwd = cwd, text = true }):wait()

  local err = nil
  if result.code == 1 then
    err = "go list:"
    if result.stdout ~= nil and result.stdout ~= "" then
      err = err .. " " .. result.stdout
    end
    if result.stdout ~= nil and result.stderr ~= "" then
      err = err .. " " .. result.stderr
    end
    logger.warn({ "Go list error: ", err })
  end

  local output = result.stdout or ""

  local golist_output = json.decode_from_string(output)
  logger.debug({ "JSON-decoded 'go list' output: ", golist_output })
  return golist_output, err
end

function M.golist_command()
  -- NOTE: original command can contain a lot of data:
  -- local cmd = { "go", "list", "-json" }

  -- NOTE: optimized command only outputs fields needed:
  local cmd = {
    "go",
    "list",
    "-f",
    [[{
    "Dir": "{{.Dir}}",
    "ImportPath": "{{.ImportPath}}",
    "Name": "{{.Name}}",
    "TestGoFiles": [{{range $i, $f := .TestGoFiles}}{{if ne $i 0}},{{end}}"{{$f}}"{{end}}],
    "XTestGoFiles": [{{range $i, $f := .XTestGoFiles}}{{if ne $i 0}},{{end}}"{{$f}}"{{end}}],
    "Module": { "GoMod": "{{.Module.GoMod}}" }
    }]],
  }

  local go_list_args = options.get().go_list_args
  if type(go_list_args) == "function" then
    go_list_args = go_list_args()
  end
  vim.list_extend(cmd, go_list_args or {})
  vim.list_extend(cmd, { "./..." })
  return cmd
end

function M.test_command_in_package(package_or_path)
  local go_test_required_args = { package_or_path }
  local cmd, json_filepath = M.test_command(go_test_required_args)
  return cmd, json_filepath
end

function M.test_command_in_package_with_regexp(package_or_path, regexp)
  local go_test_required_args = { package_or_path, "-run", regexp }
  local cmd, json_filepath = M.test_command(go_test_required_args)
  return cmd, json_filepath
end

function M.test_command(go_test_required_args)
  --- The runner to use for running tests.
  --- @type string
  local runner = M.runner_fallback(options.get().runner)

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

  logger.info("Test command: " .. table.concat(cmd, " "))

  return cmd, json_filepath
end

function M.go_test(go_test_required_args)
  local cmd = { "go", "test", "-json" }
  local args = options.get().go_test_args
  if type(args) == "function" then
    args = args()
  end
  cmd = vim.list_extend(vim.deepcopy(cmd), args)
  cmd = vim.list_extend(vim.deepcopy(cmd), go_test_required_args)
  return cmd
end

function M.gotestsum(go_test_required_args, json_filepath)
  local cmd = { "gotestsum", "--jsonfile=" .. json_filepath }
  local gotestsum_args = options.get().gotestsum_args
  if type(gotestsum_args) == "function" then
    gotestsum_args = gotestsum_args()
  end
  local go_test_args = options.get().go_test_args
  if type(go_test_args) == "function" then
    go_test_args = go_test_args()
  end
  cmd = vim.list_extend(vim.deepcopy(cmd), gotestsum_args)
  cmd = vim.list_extend(vim.deepcopy(cmd), { "--" })
  cmd = vim.list_extend(vim.deepcopy(cmd), go_test_args)
  cmd = vim.list_extend(vim.deepcopy(cmd), go_test_required_args)
  return cmd
end

function M.runner_fallback(executable)
  if M.system_has(executable) == false then
    options.set({ runner = "go" })
    return options.get().runner
  end
  return options.get().runner
end

function M.system_has(executable)
  if vim.fn.executable(executable) == 0 then
    logger.warn("Executable not found: " .. executable)
    return false
  end
  return true
end

return M
