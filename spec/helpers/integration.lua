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

  -- Execute the command synchronously to avoid integrated strategy hangs
  local strategy_result = nio.tests.with_async_context(function()
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

  assert(strategy_result, "Failed to get strategy result")

  -- If available, process any captured stdout/stderr to seed cached results.
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
