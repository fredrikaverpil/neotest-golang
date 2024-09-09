--- Helpers to build the command and context around running all tests of a file.

local logger = require("neotest-golang.logging")
local lib = require("neotest-golang.lib")

local M = {}

--- Build runspec for a directory.
--- @param pos neotest.Position
--- @param tree neotest.Tree
--- @return neotest.RunSpec | neotest.RunSpec[] | nil
function M.build(pos, tree)
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
  local golist_data, golist_error = lib.cmd.golist_data(go_mod_folderpath)

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
  local pos_path_foldername = vim.fn.fnamemodify(pos.path, ":h")

  for _, golist_item in ipairs(golist_data) do
    if golist_item.TestGoFiles ~= nil then
      if
        pos_path_foldername == golist_item.Dir
        and vim.tbl_contains(golist_item.TestGoFiles, pos_path_filename)
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
    cwd = go_mod_folderpath,
    context = context,
  }

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
