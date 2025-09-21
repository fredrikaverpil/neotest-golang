--- Helper functions building the test command to execute.

local json = require("neotest-golang.lib.json")
local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")
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
--- @return string[], table|nil
function M.test_command_in_package(package_or_path)
  local go_test_required_args = { package_or_path }
  local cmd, exec_context = M.test_command(go_test_required_args, true)
  return cmd, exec_context
end

--- Build test command for running specific tests matching a regexp in a package
--- @param package_or_path string Package import path or directory path
--- @param regexp string Regular expression to match test names
--- @return string[], table|nil
function M.test_command_in_package_with_regexp(package_or_path, regexp)
  local go_test_required_args = { package_or_path, "-run", regexp }
  local cmd, exec_context = M.test_command(go_test_required_args, true)
  return cmd, exec_context
end

--- Build test command using injected runner strategy
---@param go_test_required_args string[] The required arguments, necessary for the test command
---@param fallback boolean Control runner fallback behavior, used primarily by tests
---@return string[], table|nil
function M.test_command(go_test_required_args, fallback)
  local opts = options.get()
  local runner = opts.runner_instance

  if not runner then
    logger.error(
      "No runner instance available. Ensure options.setup() was called."
    )
    return {}, nil
  end

  if fallback and not runner:is_available() then
    local fallback_runner_name = runner:get_fallback()
    logger.warn(
      "Runner '"
        .. runner.name
        .. "' not available, falling back to '"
        .. fallback_runner_name
        .. "'",
      true
    )
    local runner_lib = require("neotest-golang.lib.runners")
    runner = runner_lib.create_runner(fallback_runner_name, false)
  end

  local cmd, exec_context =
    runner:get_test_command(go_test_required_args, fallback)

  logger.info("Test command: " .. table.concat(cmd, " "))

  return cmd, exec_context
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
