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

--- Assert that a test result has the expected status
--- @param results table<string, neotest.Result>
--- @param pos_id string Position ID to check
--- @param expected_status string Expected status ("passed", "failed", "skipped")
function M.assert_test_status(results, pos_id, expected_status)
  assert(results[pos_id], "No result found for position: " .. pos_id)
  assert.are.equal(
    expected_status,
    results[pos_id].status,
    "Test "
      .. pos_id
      .. " expected "
      .. expected_status
      .. " but got "
      .. tostring(results[pos_id].status)
  )
end

--- Get a list of all position IDs in a tree
--- @param tree neotest.Tree
--- @return string[] List of position IDs
function M.get_position_ids(tree)
  local ids = {}
  for _, pos in tree:iter() do
    table.insert(ids, pos.id)
  end
  return ids
end

--- Assert all discovered positions have results
--- @param tree neotest.Tree
--- @param results table<string, neotest.Result>
function M.assert_all_positions_have_results(tree, results)
  for _, pos in tree:iter() do
    -- Note: Not all positions may have results in streaming mode,
    -- so we only warn about missing file-level results
    if pos.type == "file" then
      assert.is_truthy(
        results[pos.id],
        "Missing result for file position: " .. pos.id
      )
    end
  end
end

--- Assert complete runspec structure and basic validity
--- @param run_spec neotest.RunSpec The runspec to validate
--- @param expected_pos_id string Expected position ID in context
function M.assert_runspec_structure(run_spec, expected_pos_id)
  -- Basic runspec structure
  assert.is_truthy(run_spec, "RunSpec should exist")
  assert.are.equal("table", type(run_spec), "RunSpec should be a table")

  -- Required fields
  assert.is_truthy(run_spec.command, "RunSpec should have command")
  assert.is_truthy(run_spec.cwd, "RunSpec should have working directory")
  assert.is_truthy(run_spec.context, "RunSpec should have context")

  -- Command validation
  assert.are.equal("table", type(run_spec.command), "Command should be table")
  assert.is_true(#run_spec.command > 0, "Command should not be empty")
  assert.are.equal("go", run_spec.command[1], "First command should be 'go'")

  -- Working directory validation
  assert.are.equal("string", type(run_spec.cwd), "CWD should be string")
  assert.is_true(run_spec.cwd:len() > 0, "CWD should not be empty")
  assert.is_true(vim.fn.isdirectory(run_spec.cwd) == 1, "CWD should exist")

  -- Context validation
  M.assert_context_structure(run_spec.context, expected_pos_id)
end

--- Assert runspec context structure and validity
--- @param context RunspecContext The context to validate
--- @param expected_pos_id string Expected position ID
function M.assert_context_structure(context, expected_pos_id)
  assert.is_truthy(context, "Context should exist")
  assert.are.equal("table", type(context), "Context should be a table")

  -- Required context fields
  assert.are.equal("string", type(context.pos_id), "pos_id should be string")
  assert.are.equal(
    expected_pos_id,
    context.pos_id,
    "pos_id should match expected"
  )
  assert.are.equal(
    "table",
    type(context.golist_data),
    "golist_data should be table"
  )
  assert.are.equal(
    "function",
    type(context.stop_stream),
    "stop_stream should be function"
  )

  -- Validate golist_data contains valid package information
  assert.is_true(#context.golist_data > 0, "golist_data should not be empty")
  local found_valid_package = false
  for _, pkg in ipairs(context.golist_data) do
    if pkg.ImportPath and pkg.Dir then
      found_valid_package = true
      assert.are.equal(
        "string",
        type(pkg.ImportPath),
        "ImportPath should be string"
      )
      assert.are.equal("string", type(pkg.Dir), "Dir should be string")
      break
    end
  end
  assert.is_true(
    found_valid_package,
    "Should find at least one valid package in golist_data"
  )

  -- Optional context fields validation
  if context.errors then
    assert.are.equal(
      "table",
      type(context.errors),
      "errors should be table when present"
    )
  end

  if context.test_output_json_filepath then
    assert.are.equal(
      "string",
      type(context.test_output_json_filepath),
      "test_output_json_filepath should be string when present"
    )
  end

  if context.is_dap_active ~= nil then
    assert.are.equal(
      "boolean",
      type(context.is_dap_active),
      "is_dap_active should be boolean when present"
    )
  end
end

--- Assert command contains expected parts/flags
--- @param run_spec neotest.RunSpec The runspec to check
--- @param expected_parts table<string> Expected command parts/flags
--- @param description string Optional description for better error messages
function M.assert_command_contains(run_spec, expected_parts, description)
  assert.is_truthy(run_spec.command, "RunSpec should have command")
  local command_str = table.concat(run_spec.command, " ")

  for _, part in ipairs(expected_parts or {}) do
    assert.is_true(
      command_str:find(part, 1, true) ~= nil,
      (description or "Command")
        .. " should contain: '"
        .. part
        .. "' in: "
        .. command_str
    )
  end
end

--- Assert command does NOT contain specific parts/flags
--- @param run_spec neotest.RunSpec The runspec to check
--- @param forbidden_parts table<string> Parts that should NOT be in command
--- @param description string Optional description for better error messages
function M.assert_command_excludes(run_spec, forbidden_parts, description)
  assert.is_truthy(run_spec.command, "RunSpec should have command")
  local command_str = table.concat(run_spec.command, " ")

  for _, part in ipairs(forbidden_parts or {}) do
    assert.is_true(
      command_str:find(part, 1, true) == nil,
      (description or "Command")
        .. " should NOT contain: '"
        .. part
        .. "' in: "
        .. command_str
    )
  end
end

--- Assert runspec environment variables
--- @param run_spec neotest.RunSpec The runspec to check
--- @param expected_env table<string, string> Expected environment variables
function M.assert_runspec_env(run_spec, expected_env)
  if expected_env and next(expected_env) then
    assert.is_truthy(run_spec.env, "RunSpec should have env when expected")
    assert.are.equal("table", type(run_spec.env), "env should be table")

    for key, value in pairs(expected_env) do
      assert.are.equal(
        value,
        run_spec.env[key],
        "Environment variable " .. key .. " should equal " .. value
      )
    end
  end
end

--- Assert DAP strategy configuration
--- @param run_spec neotest.RunSpec The runspec to check
--- @param should_have_dap boolean Whether DAP should be configured
function M.assert_dap_strategy(run_spec, should_have_dap)
  if should_have_dap then
    assert.is_truthy(run_spec.strategy, "RunSpec should have strategy for DAP")
    assert.is_truthy(
      run_spec.context.is_dap_active,
      "Context should indicate DAP is active"
    )
    assert.are.equal(
      true,
      run_spec.context.is_dap_active,
      "DAP should be active"
    )
  else
    assert.is_falsy(run_spec.context.is_dap_active, "DAP should not be active")
  end
end

--- Assert gotestsum-specific runspec configuration
--- @param run_spec neotest.RunSpec The runspec to check
--- @param should_use_gotestsum boolean Whether gotestsum should be used
function M.assert_gotestsum_config(run_spec, should_use_gotestsum)
  local command_str = table.concat(run_spec.command, " ")

  if should_use_gotestsum then
    assert.is_true(
      command_str:find("gotestsum") ~= nil,
      "Command should use gotestsum: " .. command_str
    )
    assert.is_truthy(
      run_spec.context.test_output_json_filepath,
      "Should have JSON output file for gotestsum"
    )
  else
    assert.is_true(
      command_str:find("gotestsum") == nil,
      "Command should NOT use gotestsum: " .. command_str
    )
  end
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

--- Comprehensive runspec validation with common patterns
--- @param run_spec neotest.RunSpec The runspec to validate
--- @param expected_pos_id string Expected position ID
--- @param opts table Optional configuration
---   - runner: "go" | "gotestsum"
---   - required_flags: table<string> Flags that must be present
---   - forbidden_flags: table<string> Flags that must NOT be present
---   - env: table<string, string> Expected environment variables
---   - dap: boolean Whether DAP should be active
function M.assert_runspec_comprehensive(run_spec, expected_pos_id, opts)
  opts = opts or {}

  -- Basic structure validation
  M.assert_runspec_structure(run_spec, expected_pos_id)

  -- Command validation based on runner
  if opts.runner == "gotestsum" then
    M.assert_gotestsum_config(run_spec, true)
  else
    M.assert_gotestsum_config(run_spec, false)
  end

  -- Required flags
  if opts.required_flags then
    M.assert_command_contains(run_spec, opts.required_flags, "Required flags")
  end

  -- Forbidden flags
  if opts.forbidden_flags then
    M.assert_command_excludes(run_spec, opts.forbidden_flags, "Forbidden flags")
  end

  -- Environment variables
  if opts.env then
    M.assert_runspec_env(run_spec, opts.env)
  end

  -- DAP strategy
  if opts.dap ~= nil then
    M.assert_dap_strategy(run_spec, opts.dap)
  end
end

-- Load assertion helpers
local assert_helpers = dofile(vim.uv.cwd() .. "/tests/helpers/assert.lua")

-- Compatibility aliases for the new generic assertion approach
---@param actual_result neotest.Result
---@param expected_result neotest.Result
---@param context_name string?
function M.assert_result_with_dynamic_fields(
  actual_result,
  expected_result,
  context_name
)
  assert_helpers.assert_neotest_result(
    actual_result,
    expected_result,
    { "output" },
    context_name
  )
end

---@param actual_context RunspecContext
---@param expected_context RunspecContext
---@param context_name string?
function M.assert_context_with_dynamic_fields(
  actual_context,
  expected_context,
  context_name
)
  assert_helpers.assert_runspec_context(
    actual_context,
    expected_context,
    { "golist_data", "stop_stream" },
    context_name
  )
end

return M
