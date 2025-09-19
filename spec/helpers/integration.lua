--- Integration test utilities for end-to-end Go test execution

---@class AdapterExecutionResult
---@field tree neotest.Tree The discovered test tree
---@field results table<string, neotest.Result> The processed test results
---@field run_spec neotest.RunSpec The built run specification
---@field strategy_result table The execution result from strategy

local M = {}

--- Execute command and return strategy result
--- @param run_spec neotest.RunSpec The built run specification
--- @return table strategy_result The execution result from strategy
local function execute_command(run_spec)
  local nio = require("nio")

  return nio.tests.with_async_context(function()
    -- Normalize env and cwd
    local env = run_spec.env
    if env and vim.tbl_isempty(env) then
      env = nil
    end

    print("Go test command:", vim.inspect(run_spec.command))
    print("Working directory:", run_spec.cwd)

    -- Run the process synchronously
    local sys = vim
      .system(run_spec.command, {
        cwd = run_spec.cwd,
        env = env,
        text = true,
      })
      :wait()

    -- Persist stdout/stderr to a temp file for debugging/fallbacks
    local output_path = nil
    if
      (sys.stdout and sys.stdout ~= "") or (sys.stderr and sys.stderr ~= "")
    then
      output_path = vim.fs.normalize(vim.fn.tempname())
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
      vim.fn.writefile(lines, output_path)
    end

    print("Exit code:", sys.code, "Output path:", output_path)

    return {
      code = sys.code or 1,
      output = output_path,
    }
  end)
end

--- Execute a real test using the adapter's build_spec and results methods directly
--- This bypasses neotest.run.run and calls the adapter interface directly
---
--- Position ID Format Examples:
--- "/path/to/directory"                                    -- Directory (all tests)
--- "/path/to/file_test.go"                                 -- File (all tests in file)
--- "/path/to/file_test.go::TestFunction"                   -- Specific test
--- "/path/to/file_test.go::TestFunction::\"SubTest\""        -- Subtest
--- "/path/to/file_test.go::TestFunction::\"SubTest\"::\"TableTest\"" -- Nested subtest
---
--- @param position_id string Neotest position ID (directory, file, or test position)
--- @return AdapterExecutionResult result Complete execution result
function M.execute_adapter_direct(position_id)
  -- Validate arguments
  assert(position_id, "position_id is required")
  assert(type(position_id) == "string", "position_id must be a string")

  -- Parse position ID to extract components
  local base_path, test_components = position_id:match("^([^:]+)(.*)")
  local has_test_parts = test_components and test_components ~= ""

  -- Infer intent from position ID format
  local is_file = vim.fn.filereadable(base_path) == 1
  local is_dir = vim.fn.isdirectory(base_path) == 1

  local inferred_type
  if has_test_parts then
    -- Contains :: = test or subtest execution
    inferred_type = "test"
    assert(
      is_file,
      "Test position ID must reference a readable file: " .. base_path
    )
    assert(
      vim.endswith(base_path, "_test.go"),
      "Test position ID must reference a Go test file ending in '_test.go': "
        .. base_path
    )
  elseif is_file then
    -- File path without :: = file execution
    inferred_type = "file"
    assert(
      vim.endswith(base_path, "_test.go"),
      "File position ID must reference a Go test file ending in '_test.go': "
        .. base_path
    )
  elseif is_dir then
    -- Directory path = directory execution
    inferred_type = "dir"
  else
    error(
      "Position ID must reference a readable file or directory: " .. base_path
    )
  end

  -- Extract test pattern from position ID for test execution
  local test_pattern = nil
  if inferred_type == "test" then
    -- Use existing utility to convert position ID to Go test name
    local convert = require("neotest-golang.lib.convert")
    local go_test_name = convert.pos_id_to_go_test_name(position_id)
    if go_test_name then
      -- Extract just the main test name (before any subtests)
      local main_test_name = go_test_name:match("^([^/]+)")
      test_pattern = "^" .. main_test_name .. "$"
    else
      error(
        "Invalid test position ID format. Expected '::TestName' after file path: "
          .. position_id
      )
    end
  end

  local nio = require("nio")
  local adapter = require("neotest-golang")

  -- Set up test stream strategy for integration tests
  local lib_stream = require("neotest-golang.lib.stream")
  local test_strategy = require("neotest-golang.lib.stream.test_strategy")
  lib_stream.set_test_strategy(test_strategy)

  local tree, full_tree

  if inferred_type == "file" then
    -- File position: discover all tests in the file
    tree = nio.tests.with_async_context(adapter.discover_positions, base_path)
    assert(tree, "Failed to discover test positions in " .. base_path)
    full_tree = tree
  elseif inferred_type == "dir" then
    -- Directory position: build composite tree from all test files
    local test_files = {}
    local dir_scan = vim.fn.readdir(base_path, function(name)
      return vim.endswith(name, "_test.go")
    end)

    for _, file in ipairs(dir_scan or {}) do
      table.insert(test_files, base_path .. "/" .. file)
    end

    local all_nodes = {}
    local file_trees = {}

    -- Discover positions for each test file
    for _, file_path in ipairs(test_files) do
      local file_tree =
        nio.tests.with_async_context(adapter.discover_positions, file_path)
      if file_tree then
        table.insert(file_trees, file_tree)
        for _, node in file_tree:iter_nodes() do
          table.insert(all_nodes, node)
        end
      end
    end

    -- Create directory tree structure
    local dir_position = {
      type = "dir",
      path = base_path,
      name = vim.fn.fnamemodify(base_path, ":t"),
      id = base_path,
      range = { 0, 0, 0, 0 },
    }

    tree = {
      _key = function()
        return base_path
      end,
      data = function()
        return dir_position
      end,
      children = function()
        return file_trees
      end,
      iter_nodes = function()
        local nodes = {
          {
            data = function()
              return dir_position
            end,
          },
        }
        for _, node in ipairs(all_nodes) do
          table.insert(nodes, node)
        end
        return pairs(nodes)
      end,
      iter = function()
        local positions = { [base_path] = dir_position }
        for _, node in ipairs(all_nodes) do
          local pos = node:data()
          positions[pos.id] = pos
        end
        return pairs(positions)
      end,
    }
    full_tree = tree
  elseif inferred_type == "test" then
    -- Test position: find specific test position that matches the position ID
    full_tree =
      nio.tests.with_async_context(adapter.discover_positions, base_path)
    assert(full_tree, "Failed to discover test positions in " .. base_path)

    local target_test_position = nil
    for _, node in full_tree:iter_nodes() do
      local pos = node:data()
      -- Match the exact position ID
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
  end

  -- Build run spec
  ---@type neotest.RunArgs
  local run_args = { tree = tree, strategy = "integrated" }
  if test_pattern then
    run_args.extra_args = { "-run", test_pattern }
  end

  local run_spec = adapter.build_spec(run_args)
  assert(run_spec, "Failed to build run spec for " .. position_id)
  assert(run_spec.command, "Run spec should have a command")

  -- Execute the command
  local strategy_result = execute_command(run_spec)
  assert(strategy_result, "Failed to get strategy result")

  -- Process test output manually to seed cached results
  if strategy_result.output then
    M.process_test_output_manually(
      full_tree,
      run_spec.context.golist_data,
      strategy_result.output,
      run_spec.context
    )
  end

  -- Process results through adapter
  local results = nio.tests.with_async_context(
    adapter.results,
    run_spec,
    strategy_result,
    full_tree
  )

  -- Reset test strategy to avoid state leakage between tests
  lib_stream.set_test_strategy(nil)

  ---@type AdapterExecutionResult
  return {
    tree = full_tree,
    results = results,
    run_spec = run_spec,
    strategy_result = strategy_result,
  }
end

--- Normalize Windows paths for cross-platform testing
--- @param path string
--- @return string
function M.normalize_path(path)
  local utils = dofile(vim.uv.cwd() .. "/spec/helpers/utils.lua")
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
  local results_stream = require("neotest-golang.results_stream")

  -- Read the raw output (guard if file missing)
  local raw_output = {}
  if output_path and vim.fn.filereadable(output_path) == 1 then
    raw_output = async.fn.readfile(output_path)
  end

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
  local accum = {}

  for _, gotest_event in ipairs(gotest_output) do
    accum = results_stream.process_event(
      golist_data,
      accum,
      gotest_event,
      position_lookup
    )
  end

  -- Convert to stream results
  local individual_results = results_stream.make_stream_results(accum)

  -- Populate the cached results so that results_finalize.test_results can access them
  for pos_id, result in pairs(individual_results) do
    lib.stream.cached_results[pos_id] = result
  end

  return individual_results
end

return M
