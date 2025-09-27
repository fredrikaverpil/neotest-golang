--- Async integration test utilities for reproducing race conditions
--- Unlike regular integration.lua, this uses real streaming to expose concurrency bugs
---
--- This module provides async execution modes designed to trigger race conditions:
---
--- 1. Single Async Execution (with real streaming)
---    execute_adapter_async(position_id)
---    Uses real async streaming without test strategy override to expose race conditions
---
--- 2. Concurrent Execution (multiple tests in parallel)
---    execute_concurrent_tests(position_ids)
---    Uses nio.run() to launch multiple tests simultaneously, triggering tempfile races

local lib = require("neotest-golang.lib")
local options = require("neotest-golang.options")

---@class AsyncAdapterExecutionResult
---@field tree neotest.Tree The discovered test tree
---@field results table<string, neotest.Result> The processed test results
---@field run_spec neotest.RunSpec The built run specification
---@field strategy_result table The execution result from strategy

local M = {}

--- Execute adapter using real async streaming (no test strategy override)
--- This exposes the actual concurrency behavior that can trigger race conditions
---
--- @param position_id string Neotest position ID (directory, file, or test position)
--- @return AsyncAdapterExecutionResult result Complete execution result
function M.execute_adapter_async(position_id)
  -- Validate arguments
  assert(position_id, "position_id is required")
  assert(type(position_id) == "string", "position_id must be a string")

  local nio = require("nio")
  local adapter = require("neotest-golang")
  local async = require("neotest.async")

  -- CRITICAL: Do NOT set test strategy - use real live streaming
  -- This allows concurrent stream processing that can expose race conditions
  local lib_stream = require("neotest-golang.lib.stream")
  -- lib_stream.set_test_strategy(test_strategy) -- INTENTIONALLY COMMENTED OUT

  -- Parse position ID (reuse logic from integration.lua)
    local base_path, test_components
    local double_colon_pos = position_id:find("::")
    if double_colon_pos then
      base_path = position_id:sub(1, double_colon_pos - 1)
      test_components = position_id:sub(double_colon_pos)
    else
      base_path = position_id
      test_components = ""
    end
    local has_test_parts = test_components and test_components ~= ""

    -- Validate path exists
    local is_file = vim.fn.filereadable(base_path) == 1
    local is_dir = vim.fn.isdirectory(base_path) == 1

    local inferred_type
    if has_test_parts then
      inferred_type = "test"
      assert(
        is_file,
        "Test position ID must reference a readable file: " .. base_path
      )
      assert(
        vim.endswith(base_path, "_test.go"),
        "Test position ID must reference a Go test file: " .. base_path
      )
    elseif is_file then
      inferred_type = "file"
      assert(
        vim.endswith(base_path, "_test.go"),
        "File position ID must reference a Go test file: " .. base_path
      )
    elseif is_dir then
      inferred_type = "dir"
    else
      error(
        "Position ID must reference a readable file or directory: " .. base_path
      )
    end

    -- Discover test tree
    local tree, full_tree
    if inferred_type == "file" then
      tree = adapter.discover_positions(base_path)
      assert(tree, "Failed to discover test positions in " .. base_path)
      full_tree = tree
    elseif inferred_type == "test" then
      full_tree = adapter.discover_positions(base_path)
      assert(full_tree, "Failed to discover test positions in " .. base_path)

      -- Find specific test position
      local target_test_position = nil
      for _, node in full_tree:iter_nodes() do
        local pos = node:data()
        if pos.id == position_id then
          target_test_position = node
          break
        end
      end
      assert(
        target_test_position,
        "Could not find test matching position ID: " .. position_id
      )
      tree = target_test_position
    else
      error("Directory async testing not yet implemented")
    end

    -- Build run spec with test pattern if needed
    local run_args = { tree = tree, strategy = "integrated" }
    if inferred_type == "test" then
      local convert = require("neotest-golang.lib.convert")
      local go_test_name = convert.pos_id_to_go_test_name(position_id)
      if go_test_name then
        local main_test_name = go_test_name:match("^([^/]+)")
        run_args.extra_args = { "-run", "^" .. main_test_name .. "$" }
      end
    end

    local run_spec = adapter.build_spec(run_args)
    assert(run_spec, "Failed to build run spec for " .. position_id)
    assert(run_spec.command, "Run spec should have a command")

    print("🚀 Async test command:", vim.inspect(run_spec.command))
    print("📁 Working directory:", run_spec.cwd)

    print("📊 Running test async without test strategy override...")

    -- CRITICAL: Don't set test strategy to force real streaming
    -- This ensures concurrent tempfile creation in results_stream.lua

    -- Execute the command to get real output for streaming processing
    local strategy_result
    do
      -- Normalize env
      local env = run_spec.env
      if env and vim.tbl_isempty(env) then
        env = nil
      end

      -- Run the process asynchronously to trigger real concurrency
      local future = nio.control.future()
      local handle = vim.system(run_spec.command, {
        cwd = run_spec.cwd,
        env = env,
        text = true,
      }, function(obj)
        future.set(obj)
      end)

      local sys = future.wait()

      -- Create temp file with output (similar to integration.lua)
      local output_path = nil
      if (sys.stdout and sys.stdout ~= "") or (sys.stderr and sys.stderr ~= "") then
        output_path = vim.fs.normalize(async.fn.tempname())
        local lines = {}
        if sys.stdout and sys.stdout ~= "" then
          for line in sys.stdout:gmatch("[^\r\n]+") do
            table.insert(lines, line)
          end
        end
        if sys.stderr and sys.stderr ~= "" then
          table.insert(lines, "")
          table.insert(lines, "=== stderr ===")
          for line in sys.stderr:gmatch("[^\r\n]+") do
            table.insert(lines, line)
          end
        end
        async.fn.writefile(lines, output_path)
      end

      strategy_result = {
        code = sys.code or 1,
        output = output_path,
      }
    end

    -- Process test output manually to populate streaming results cache
    -- This is what triggers the tempfile creation in results_stream.lua
    if strategy_result.output then
      local integration = require("spec.helpers.integration")
      integration.process_test_output_manually(
        full_tree,
        run_spec.context.golist_data,
        strategy_result.output,
        run_spec.context
      )
    end

    -- Process results through adapter to get final results with temp files
    local results = adapter.results(run_spec, strategy_result, full_tree)

    return {
      tree = full_tree,
      results = results,
      run_spec = run_spec,
      strategy_result = strategy_result,
    }
end

--- Execute multiple tests concurrently to trigger race conditions
--- @param position_ids string[] List of position IDs to run concurrently
--- @return AsyncAdapterExecutionResult[] results Array of execution results
function M.execute_concurrent_tests(position_ids)
  assert(position_ids and #position_ids > 0, "position_ids cannot be empty")

  local nio = require("nio")

  return nio.tests.with_async_context(function()
    local futures = {}
    local results = {}

    print("🚀 Launching", #position_ids, "concurrent tests...")

    -- Launch all tests concurrently using nio.run + future pattern
    for i, position_id in ipairs(position_ids) do
      local future = nio.control.future()
      futures[position_id] = future

      -- Launch each execution in parallel
      nio.run(function()
        print("🏃 Starting concurrent test", i, ":", position_id)
        local success, result = pcall(M.execute_adapter_async, position_id)
        if success then
          print("✅ Completed concurrent test", i, ":", position_id)
          future.set({ success = true, result = result })
        else
          print("❌ Failed concurrent test", i, ":", position_id, "Error:", result)
          future.set({ success = false, error = result })
        end
      end)
    end

    -- Wait for all futures to complete
    for i, position_id in ipairs(position_ids) do
      local future_result = futures[position_id].wait()
      if future_result.success then
        table.insert(results, future_result.result)
      else
        error("Test execution failed for " .. position_id .. ": " .. future_result.error)
      end
    end

    print("🏁 All concurrent tests completed")
    return results
  end)
end

--- Stress test for tempfile race condition reproduction
--- Runs the same test multiple times concurrently to increase race probability
--- @param position_id string Single test position to run multiple times
--- @param iterations integer Number of concurrent iterations (default: 5)
--- @return AsyncAdapterExecutionResult[] results Array of execution results


return M
