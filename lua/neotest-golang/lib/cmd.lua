--- Helper functions building the test command to execute.

local async = require("neotest.async")

local cgo = require("neotest-golang.lib.cgo")
local extra_args = require("neotest-golang.lib.extra_args")
local json = require("neotest-golang.lib.json")
local logger = require("neotest-golang.lib.logging")
local options = require("neotest-golang.options")
local path = require("neotest-golang.lib.path")
require("neotest-golang.lib.types")

---@alias RunnerType "go" | "gotestsum"

local M = {}

--- Call 'go list -json {go_list_args...} ./...' to get test file data
--- @param cwd string Working directory to run 'go list' from
--- @return GoListItem[], string|nil
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
    logger.warn({ "Go list error: ", err }, true)
  end

  local output = result.stdout or ""

  ---@type GoListItem[]
  local golist_output = json.decode_from_string(output)
  logger.debug({ "JSON-decoded 'go list' output: ", golist_output })
  return golist_output, err
end

--- Build the 'go list' command with optimized output format
--- @return string[] Command array ready for execution
function M.golist_command()
  -- NOTE: original command can contain a lot of data:
  -- local cmd = { "go", "list", "-json" }

  -- NOTE: optimized command only outputs fields needed.
  -- NOTE: Dir and GoMod needs %q to escape backslashes on Windows.
  local cmd = {
    "go",
    "list",
    "-f",
    [[{
    "Dir": {{printf "%q" .Dir}},
    "ImportPath": "{{.ImportPath}}",
    "Name": "{{.Name}}",
    "TestGoFiles": [{{range $i, $f := .TestGoFiles}}{{if ne $i 0}},{{end}}"{{$f}}"{{end}}],
    "XTestGoFiles": [{{range $i, $f := .XTestGoFiles}}{{if ne $i 0}},{{end}}"{{$f}}"{{end}}],
    "Module": { "GoMod": {{printf "%q" .Module.GoMod}} }
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

--- Build test command for running all tests in a package
--- @param package_or_path string Package import path or directory path
--- @return string[], string|nil
function M.test_command_in_package(package_or_path)
  local go_test_required_args = { package_or_path }
  local cmd, json_filepath = M.test_command(go_test_required_args, true)
  return cmd, json_filepath
end

--- Build test command for running specific tests matching a regexp in a package
--- @param package_or_path string Package import path or directory path
--- @param regexp string Regular expression to match test names
--- @return string[], string|nil
function M.test_command_in_package_with_regexp(package_or_path, regexp)
  local go_test_required_args = { package_or_path, "-run", regexp }
  local cmd, json_filepath = M.test_command(go_test_required_args, true)
  return cmd, json_filepath
end

--- Build test command using configured runner (go or gotestsum)
---@param go_test_required_args string[] The required arguments, necessary for the test command
---@param fallback boolean Control runner fallback behavior, used primarily by tests
---@return string[], string|nil
function M.test_command(go_test_required_args, fallback)
  --- The runner to use for running tests.
  --- @type string
  local runner = options.get().runner
  if fallback then
    runner = M.runner_fallback(options.get().runner)
  end

  --- The filepath to write test output JSON to, if using `gotestsum`.
  --- @type string | nil
  local json_filepath = nil

  --- The final test command to execute.
  --- @type string[]
  local cmd = {}

  if runner == "go" then
    cmd = M.go_test(go_test_required_args)
  elseif runner == "gotestsum" then
    json_filepath = path.normalize_path(raw_tempname)
    cmd = M.gotestsum(go_test_required_args, json_filepath)
  end

  logger.info("Test command: " .. table.concat(cmd, " "))

  return cmd, json_filepath
end

--- Build 'go test -json' command with configured arguments
--- @param go_test_required_args string[] Required arguments for the test command
--- @return string[] Complete go test command
function M.go_test(go_test_required_args)
  local cmd = { "go", "test", "-json" }
  local args = extra_args.get().go_test_args or options.get().go_test_args
  if type(args) == "function" then
    args = args()
  end

  -- Validate CGO requirements for -race flag
  local is_valid, error_message = cgo.validate_cgo_requirements(args)
  if not is_valid then
    logger.error("CGO validation failed: " .. error_message, true)
    error("neotest-golang: " .. error_message)
  end

  cmd = vim.list_extend(vim.deepcopy(cmd), go_test_required_args)
  cmd = vim.list_extend(vim.deepcopy(cmd), args)
  return cmd
end

--- Build gotestsum command with JSON output file
--- @param go_test_required_args string[] Required arguments for the test command
--- @param json_filepath string Path to write JSON output
--- @return string[] Complete gotestsum command
function M.gotestsum(go_test_required_args, json_filepath)
  local cmd = { "gotestsum", "--jsonfile=" .. json_filepath }
  local gotestsum_args = options.get().gotestsum_args
  if type(gotestsum_args) == "function" then
    gotestsum_args = gotestsum_args()
  end
  local go_test_args = extra_args.get().go_test_args
    or options.get().go_test_args
  if type(go_test_args) == "function" then
    go_test_args = go_test_args()
  end

  -- Validate CGO requirements for -race flag
  local is_valid, error_message = cgo.validate_cgo_requirements(go_test_args)
  if not is_valid then
    logger.error("CGO validation failed: " .. error_message, true)
    error("neotest-golang: " .. error_message)
  end

  cmd = vim.list_extend(vim.deepcopy(cmd), gotestsum_args)
  cmd = vim.list_extend(vim.deepcopy(cmd), { "--" })
  cmd = vim.list_extend(vim.deepcopy(cmd), go_test_required_args)
  cmd = vim.list_extend(vim.deepcopy(cmd), go_test_args)
  return cmd
end

--- Handle runner fallback when executable is not available
--- @param executable string Name of the executable to check
--- @return RunnerType The actual runner to use after fallback
function M.runner_fallback(executable)
  if M.system_has(executable) == false then
    local opts = options.get()
    opts.runner = "go"
    options.set(opts)
    return options.get().runner
  end
  return options.get().runner
end

--- Check if an executable is available in the system PATH
--- @param executable string Name of the executable to check
--- @return boolean True if executable is found and executable
function M.system_has(executable)
  if vim.fn.executable(executable) == 0 then
    logger.warn("Executable not found: " .. executable, true)
    return false
  end
  return true
end

return M
