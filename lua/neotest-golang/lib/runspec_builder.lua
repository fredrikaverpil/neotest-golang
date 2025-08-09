--- Common runspec building utilities for neotest-golang.
--- Consolidates common patterns used across all runspecs.

local extra_args = require("neotest-golang.extra_args")
local lib = require("neotest-golang.lib")
local options = require("neotest-golang.options")
local streaming = require("neotest-golang.lib.streaming")

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

--- Setup streaming for a runspec based on runner and strategy
--- @param run_spec table The runspec to modify
--- @param tree neotest.Tree|nil The test tree (optional for single test)
--- @param golist_data table The golist data
--- @param context table The runspec context
--- @param strategy string|nil Optional strategy (e.g., "dap")
--- @param pos neotest.Position|nil Position for single test (used if tree is nil)
--- @return table The modified runspec with streaming if applicable
function M.setup_streaming(run_spec, tree, golist_data, context, strategy, pos)
  local runner = options.get().runner
  local json_filepath = context.test_output_json_filepath

  -- For gotestsum runner with JSON file output
  if runner == "gotestsum" and json_filepath then
    if pos and not tree then
      -- Single test without tree
      return streaming.setup_gotestsum_file_streaming_for_single_test(
        run_spec,
        json_filepath,
        tree,
        golist_data,
        context,
        pos,
        strategy
      )
    else
      -- Regular streaming with tree
      return streaming.setup_gotestsum_file_streaming(
        run_spec,
        json_filepath,
        tree,
        golist_data,
        context,
        strategy
      )
    end
  else
    -- Regular streaming for 'go test -json'
    if pos and not tree then
      -- Single test without tree
      return streaming.setup_streaming_for_single_test(
        run_spec,
        tree,
        golist_data,
        context,
        pos,
        strategy
      )
    else
      -- Regular streaming with tree
      return streaming.setup_streaming(
        run_spec,
        tree,
        golist_data,
        context,
        strategy
      )
    end
  end
end

return M
