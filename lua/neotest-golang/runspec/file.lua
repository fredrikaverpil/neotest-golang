--- Helpers to build the command and context around running all tests of a file.

local dap = require("neotest-golang.features.dap")
local find = require("neotest-golang.lib.find")
local lib = require("neotest-golang.lib")
local logger = require("neotest-golang.lib.logging")
local options = require("neotest-golang.options")

local M = {}

--- Build runspec for a file.
--- @param pos neotest.Position Position data for the test file
--- @param tree neotest.Tree Neotest tree containing test structure
--- @param strategy string|nil Strategy to use (e.g., "dap" for debugging)
--- @return neotest.RunSpec|nil Runspec for executing tests in the file
function M.build(pos, tree, strategy)
  if vim.tbl_isempty(tree:children()) then
    logger.warn("No tests found in file", true)
    return M.return_skipped(pos)
  end

  local go_mod_filepath = lib.find.file_upwards("go.mod", pos.path)
  if go_mod_filepath == nil then
    logger.error(
      "The selected file does not appear to be part of a valid Go module (no go.mod file found)."
    )
    return nil -- NOTE: logger.error will throw an error, but the LSP doesn't see it.
  end

  local go_mod_folderpath = lib.path.get_directory(go_mod_filepath)
  local pos_path_folderpath = lib.path.get_directory(pos.path)
  local golist_data, golist_error = lib.cmd.golist_data(pos_path_folderpath)

  local errors = nil
  if golist_error ~= nil then
    if errors == nil then
      errors = {}
    end
    table.insert(errors, golist_error)
  end

  -- find the go package that corresponds to the pos.path
  local package_name = "./..."
  local pos_path_filename = lib.path.get_filename(pos.path)

  for _, golist_item in ipairs(golist_data) do
    if golist_item.TestGoFiles ~= nil then
      if
        pos_path_folderpath == golist_item.Dir
        and vim.tbl_contains(golist_item.TestGoFiles, pos_path_filename)
      then
        package_name = golist_item.ImportPath
        break
      end
    end
    if golist_item.XTestGoFiles ~= nil then
      -- NOTE: XTestGoFiles are test files that are part of a [packagename]_test package.
      if
        pos_path_folderpath == golist_item.Dir
        and vim.tbl_contains(golist_item.XTestGoFiles, pos_path_filename)
      then
        package_name = golist_item.ImportPath
        break
      end
    end
  end

  -- find all top-level tests in pos.path
  local test_cmd = nil
  local json_filepath = nil
  local regexp = M.get_regexp(pos.path)
  if regexp ~= nil then
    test_cmd, json_filepath =
      lib.cmd.test_command_in_package_with_regexp(package_name, regexp)
  else
    -- fallback: run all tests in the package
    test_cmd, json_filepath = lib.cmd.test_command_in_package(package_name)
    -- NOTE: could also fall back to running on a per-test basis by using a bare return
  end

  local runspec_strategy = nil
  if strategy == "dap" then
    dap.assert_dap_prerequisites()
    runspec_strategy = dap.get_dap_config(pos_path_folderpath, regexp)
    logger.debug("DAP strategy used: " .. vim.inspect(runspec_strategy))
    dap.setup_debugging(pos_path_folderpath)
  end

  local env = lib.extra_args.get().env or options.get().env
  if type(env) == "function" then
    env = env()
  end

  local stream, stop_filestream =
    lib.stream.new(tree, golist_data, json_filepath)

  --- @type RunspecContext
  local context = {
    pos_id = pos.id,
    golist_data = golist_data,
    errors = errors,
    test_output_json_filepath = json_filepath,
    stop_filestream = stop_filestream,
  }

  --- @type neotest.RunSpec
  local run_spec = {
    command = test_cmd,
    cwd = pos_path_folderpath,
    context = context,
    env = env,
    stream = stream,
  }

  if runspec_strategy ~= nil then
    run_spec.strategy = runspec_strategy
    run_spec.context.is_dap_active = true
  end

  logger.debug({ "RunSpec:", run_spec })
  return run_spec
end

--- Return a skipped runspec for files with no tests
--- @param pos neotest.Position Position data for the file
--- @return neotest.RunSpec Runspec that outputs "No tests found"
function M.return_skipped(pos)
  --- @type RunspecContext
  local context = {
    pos_id = pos.id,
    golist_data = {}, -- no golist output
    stop_filestream = function() end, -- no stream to stop
  }

  --- Runspec designed for files that contain no tests.
  --- @type neotest.RunSpec
  local run_spec = {
    command = { "echo", "No tests found in file" },
    context = context,
  }
  return run_spec
end

--- Extract test function names from file and build regex pattern
--- @param filepath string Path to the test file to analyze
--- @return string|nil Regex pattern matching all test functions, or nil if none found
function M.get_regexp(filepath)
  local regexp = nil
  local lines = {}
  for line in io.lines(filepath) do
    if line:match("func Test") or line:match("func Example") then
      line = line:gsub("func ", "")
      line = line:gsub("%(.*", "")
      table.insert(lines, lib.convert.to_gotest_regex_pattern(line))
    end
  end
  if #lines > 0 then
    regexp = "^(" .. table.concat(lines, "|") .. ")$"
  end
  return regexp
end

return M
