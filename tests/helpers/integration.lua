--- Integration test utilities for end-to-end Go test execution

---@class AdapterExecutionResult
---@field tree neotest.Tree The discovered test tree
---@field results table<string, neotest.Result> The processed test results
---@field run_spec neotest.RunSpec The built run specification
---@field strategy_result table The execution result from strategy

local M = {}

--- Execute a real test using the adapter's build_spec and results methods directly
--- This bypasses neotest.run.run and calls the adapter interface directly
--- @param file_path string Absolute path to the Go test file
--- @param test_pattern string|nil Optional test pattern
--- @return AdapterExecutionResult result Complete execution result
function M.execute_adapter_direct(file_path, test_pattern)
  local nio = require("nio")
  local adapter = require("neotest-golang")

  -- Discover test positions
  ---@type neotest.Tree
  local tree =
    nio.tests.with_async_context(adapter.discover_positions, file_path)
  assert(tree, "Failed to discover test positions in " .. file_path)

  -- Build run spec
  ---@type neotest.RunArgs
  local run_args = { tree = tree }
  if test_pattern then
    run_args.extra_args = { "-run", test_pattern }
  end

  local run_spec = adapter.build_spec(run_args)
  assert(run_spec, "Failed to build run spec for " .. file_path)
  assert(run_spec.command, "Run spec should have a command")

  -- Execute the command using Neotest's integrated strategy
  ---@type neotest.Strategy
  local strategy = require("neotest.client.strategies.integrated")
  local strategy_result = nil

  -- Use nio.tests.with_async_context to properly handle async execution
  strategy_result = nio.tests.with_async_context(function()
    -- Configure the strategy if not already configured
    if not run_spec.strategy then
      run_spec.strategy = {} -- Default strategy config
    end

    -- Clear env if it's causing issues
    if run_spec.env and vim.tbl_isempty(run_spec.env) then
      run_spec.env = nil
    end

    -- IMPORTANT: Integration tests always use neotest's integrated strategy
    -- which runs the command directly. If gotestsum is configured, the command
    -- will be a gotestsum command, but the output will come through the regular
    -- stdout/stderr channels, not through file streaming like in normal usage.

    print(
      "About to create process with command:",
      vim.inspect(run_spec.command)
    )
    print("Working directory:", run_spec.cwd)

    -- Create process using the strategy
    local process = strategy(run_spec)
    assert(process, "Failed to create process")

    print("Process created, waiting for completion...")

    -- Wait for completion with timeout
    local timeout = 60000 -- 60 seconds for debugging
    local start_time = vim.uv.now()

    while not process.is_complete() and (vim.uv.now() - start_time) < timeout do
      nio.sleep(500) -- Sleep 500ms for debugging
      local elapsed = math.floor((vim.uv.now() - start_time) / 1000)
      if elapsed % 5 == 0 then
        print(
          "Still waiting for process completion... elapsed:",
          elapsed,
          "seconds"
        )
      end
    end

    if not process.is_complete() then
      print("Process timed out after 60 seconds, stopping...")
      if process.stop then
        process.stop()
      end
      error("Test execution timed out after 60 seconds")
    end

    print("Process completed successfully")

    -- Get the result - the integrated strategy result() method returns the exit code
    local exit_code = process.result and process.result() or 1
    local output_path = process.output and process.output() or nil

    print("Exit code:", exit_code, "Output path:", output_path)

    ---@type neotest.StrategyResult
    local result = {
      code = exit_code,
      output = output_path,
    }

    return result
  end)

  assert(strategy_result, "Failed to get strategy result")

  -- Process the test output manually FIRST to populate individual test results
  -- This replicates what the streaming mechanism would do during normal execution
  if strategy_result.output then
    M.process_test_output_manually(
      tree,
      run_spec.context.golist_data,
      strategy_result.output,
      run_spec.context
    )
  end

  -- Process results through adapter - this will get the cached results
  local results = nio.tests.with_async_context(
    adapter.results,
    run_spec,
    strategy_result,
    tree
  )

  ---@type AdapterExecutionResult
  return {
    tree = tree,
    results = results,
    run_spec = run_spec,
    strategy_result = strategy_result,
  }
end

--- Normalize Windows paths for cross-platform testing
--- @param path string
--- @return string
function M.normalize_path(path)
  local utils = dofile(vim.uv.cwd() .. "/tests/helpers/utils.lua")
  return utils.normalize_path(path)
end

--- Process test output manually to populate individual test results
--- This replicates the streaming mechanism but works on completed output
--- @param tree neotest.Tree The discovered test tree
--- @param golist_data table The 'go list -json' output
--- @param output_path string Path to the test output file
--- @param context table|nil The run spec context (contains gotestsum JSON file path)
--- @return table<string, neotest.Result> Individual test results
function M.process_test_output_manually(tree, golist_data, output_path, context)
  local async = require("neotest.async")
  local lib = require("neotest-golang.lib")
  local options = require("neotest-golang.options")

  -- Read the raw output
  local raw_output = async.fn.readfile(output_path)

  -- For gotestsum, we need to read from the JSON file that was created
  local gotest_output = {}
  if options.get().runner == "gotestsum" then
    -- Removed debug prints for cleaner test output

    -- For gotestsum, the actual JSON test data is in the --jsonfile, not stdout
    -- Check if we have access to the gotestsum JSON file path from context
    if context and context.test_output_json_filepath then
      local json_filepath = context.test_output_json_filepath
      local file_stat = vim.uv.fs_stat(json_filepath)
      if file_stat and file_stat.size > 0 then
        local json_lines = async.fn.readfile(json_filepath)
        gotest_output = lib.json.decode_from_table(json_lines, true)
      else
        gotest_output = lib.json.decode_from_table(raw_output, true)
      end
    else
      -- No JSON file path available, parse from stdout
      gotest_output = lib.json.decode_from_table(raw_output, true)
    end
  else
    -- Parse JSON events from go test -json output
    gotest_output = lib.json.decode_from_table(raw_output, true)
  end

  -- Build position lookup table
  local position_lookup = lib.mapping.build_position_lookup(tree, golist_data)

  -- Process events using the same logic as streaming
  local stream_lib = lib.stream
  local accum = {}

  for _, gotest_event in ipairs(gotest_output) do
    accum = stream_lib.process_event(
      golist_data,
      accum,
      gotest_event,
      position_lookup
    )
  end

  -- Convert to stream results
  local individual_results = stream_lib.make_stream_results(accum)

  -- Populate the cached results so that process.test_results can access them
  for pos_id, result in pairs(individual_results) do
    stream_lib.cached_results[pos_id] = result
  end

  return individual_results
end


return M
