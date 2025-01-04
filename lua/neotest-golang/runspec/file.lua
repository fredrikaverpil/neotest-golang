--- Helpers to build the command and context around running all tests of a file.

local logger = require("neotest-golang.logging")
local lib = require("neotest-golang.lib")
local dap = require("neotest-golang.features.dap")

local M = {}

--- Build runspec for a file.
--- @param pos neotest.Position
--- @param tree neotest.Tree
--- @param strategy string
--- @return neotest.RunSpec | neotest.RunSpec[] | nil
function M.build(pos, tree, strategy)
  if vim.tbl_isempty(tree:children()) then
    return M.return_skipped(pos)
  end

  local go_mod_filepath = lib.find.file_upwards("go.mod", pos.path)
  if go_mod_filepath == nil then
    logger.error(
      "The selected file does not appear to be part of a valid Go module (no go.mod file found)."
    )
    return nil -- NOTE: logger.error will throw an error, but the LSP doesn't see it.
  end

  local go_mod_folderpath = vim.fn.fnamemodify(go_mod_filepath, ":h")
  local pos_path_folderpath = vim.fn.fnamemodify(pos.path, ":h")
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
  local pos_path_filename = vim.fn.fnamemodify(pos.path, ":t")

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

  --- @type RunspecContext
  local context = {
    pos_id = pos.id,
    golist_data = golist_data,
    errors = errors,
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

function M.return_skipped(pos)
  --- @type RunspecContext
  local context = {
    pos_id = pos.id,
    golist_data = {}, -- no golist output
  }

  --- Runspec designed for files that contain no tests.
  --- @type neotest.RunSpec
  local run_spec = {
    command = { "echo", "No tests found in file" },
    context = context,
  }
  return run_spec
end

function M.get_regexp(filepath)
  local regexp = nil
  local lines = {}
  for line in io.lines(filepath) do
    if line:match("func Test") then
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
