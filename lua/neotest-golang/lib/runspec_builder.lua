--- Common runspec building utilities for neotest-golang.
--- Consolidates common patterns used across all runspecs.

local extra_args = require("neotest-golang.extra_args")
local lib = require("neotest-golang.lib")
local options = require("neotest-golang.options")

local M = {}

--- Get golist data with error handling
--- @param path string The path to get golist data for
--- @return table, table|nil golist_data, errors
function M.get_golist_data(path)
  local golist_data, golist_error = lib.cmd.golist_data(path)
  
  local errors = nil
  if golist_error ~= nil then
    errors = { golist_error }
  end
  
  return golist_data, errors
end

--- Get environment variables from extra_args or options
--- @return table|nil
function M.get_environment()
  local env = extra_args.get().env or options.get().env
  if type(env) == "function" then
    env = env()
  end
  return env
end

--- Build a base context for runspecs
--- @param pos_id string The position ID
--- @param golist_data table The golist data
--- @param errors table|nil Any errors that occurred
--- @param json_filepath string|nil Optional JSON output filepath
--- @return table The context object
function M.build_base_context(pos_id, golist_data, errors, json_filepath)
  return {
    pos_id = pos_id,
    golist_data = golist_data,
    errors = errors,
    test_output_json_filepath = json_filepath,
  }
end

--- Build a base runspec
--- @param command table The test command
--- @param cwd string The working directory
--- @param context table The context object
--- @param env table|nil Environment variables
--- @return table The runspec object
function M.build_base_runspec(command, cwd, context, env)
  return {
    command = command,
    cwd = cwd,
    context = context,
    env = env,
  }
end

return M