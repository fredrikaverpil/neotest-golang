--- Utilities for executing real Go tests through Neotest

local M = {}

--- Execute a real test using the adapter's build_spec and results methods directly
--- This bypasses neotest.run.run and calls the adapter interface directly
--- @param file_path string Absolute path to the Go test file
--- @param test_pattern string|nil Optional test pattern
--- @return neotest.Tree tree The discovered test tree
--- @return table<string, neotest.Result> results The actual test results
function M.execute_adapter_direct(file_path, test_pattern)
  local nio = require("nio")
  local adapter = require("neotest-golang")

  -- Discover test positions
  local tree =
    nio.tests.with_async_context(adapter.discover_positions, file_path)
  assert(tree, "Failed to discover test positions in " .. file_path)

  -- Build run spec
  local run_args = { tree = tree }
  if test_pattern then
    run_args.extra_args = { "-run", test_pattern }
  end

  local run_spec = adapter.build_spec(run_args)
  assert(run_spec, "Failed to build run spec for " .. file_path)
  assert(run_spec.command, "Run spec should have a command")

  -- Execute the command using Neotest's integrated strategy
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

    print(
      "About to create process with command:",
      vim.inspect(run_spec.command)
    )
    print("Working directory:", run_spec.cwd)

    -- Create process using the strategy
    local process = strategy(run_spec)
    assert(process, "Failed to create process")

    print("Process created, waiting for completion...")

    -- Let the integrated strategy handle the waiting - don't manually wait
    -- The strategy's result() method is blocking and will wait for completion

    -- Get the result - this is a blocking call that waits for process completion
    -- The integrated strategy handles timeouts internally
    local exit_code = process.result and process.result() or 1
    local output_path = process.output and process.output() or nil

    print("Process completed successfully")
    print("Exit code:", exit_code, "Output path:", output_path)

    local result = {
      code = exit_code,
      output = output_path,
    }

    return result
  end)

  assert(strategy_result, "Failed to get strategy result")

  -- Process results through adapter
  local results = nio.tests.with_async_context(
    adapter.results,
    run_spec,
    strategy_result,
    tree
  )

  return tree, results, run_spec, strategy_result
end

--- Normalize Windows paths for cross-platform testing
--- @param path string
--- @return string
function M.normalize_path(path)
  if vim.fn.has("win32") == 1 then
    return path:gsub("/", "\\")
  end
  return path
end

--- Assert that a test result has the expected status
--- @param results table<string, neotest.Result>
--- @param pos_id string Position ID to check
--- @param expected_status string Expected status ("passed", "failed", "skipped")
function M.assert_test_status(results, pos_id, expected_status)
  assert(results[pos_id], "No result found for position: " .. pos_id)
  local actual_status = results[pos_id].status
  if actual_status ~= expected_status then
    error(
      "Test "
        .. pos_id
        .. " expected "
        .. expected_status
        .. " but got "
        .. tostring(actual_status)
    )
  end
end

--- Assert that test output contains expected content
--- @param results table<string, neotest.Result>
--- @param pos_id string Position ID to check
--- @param expected_content string Content that should be in output
function M.assert_output_contains(results, pos_id, expected_content)
  assert(results[pos_id], "No result found for position: " .. pos_id)
  assert(results[pos_id].output, "No output found for position: " .. pos_id)

  local output_lines = vim.fn.readfile(results[pos_id].output)
  local output_text = table.concat(output_lines, "\n")
  assert(
    output_text:find(expected_content, 1, true),
    "Output for "
      .. pos_id
      .. " does not contain: "
      .. expected_content
      .. "\nActual output:\n"
      .. output_text
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

return M
