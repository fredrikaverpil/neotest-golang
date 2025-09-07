--- Integration test utilities for end-to-end Go test execution

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
