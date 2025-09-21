--- This file is centered around the parsing/processing of test execution output
--- and assembling of the final results to hand back over to Neotest.

local async = require("neotest.async")

local lib = require("neotest-golang.lib")
local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")
require("neotest-golang.lib.types")

local M = {}

--- Finalize test results by creating root result and populating missing aggregated results.
--- This is the main orchestrator that processes test output and fills in missing file/directory results.
--- @param spec neotest.RunSpec
--- @param result neotest.StrategyResult
--- @param tree neotest.Tree
--- @return table<string, neotest.Result>
function M.test_results(spec, result, tree)
  --- @type RunspecContext
  local context = spec.context

  --- @type neotest.Position
  local pos = tree:data()

  -- Stop streaming first to ensure all results are cached
  spec.context.stop_filestream()

  -- Get final cached results after streaming is complete (atomic transfer)
  ---@type table<string, neotest.Result>
  local results = lib.stream.transfer_cached_results()

  --- Final Neotest results, the way Neotest wants it returned.
  --- @type table<string, neotest.Result>
  local skipped_result = {}

  if context.is_dap_active then
    -- return early if test result processing is not desired.
    skipped_result[context.pos_id] = {
      status = "skipped",
    }
    return skipped_result
  end

  --- The runner to use for running tests.
  --- @type string
  local runner = options.get().runner

  --- The output from the test command, as captured by stdout.
  --- @type table<string>
  local output = {}
  if runner == "go" then
    if not result.output then
      logger.error("Go test output file is missing")
    end
    if vim.fn.filereadable(result.output) ~= 1 then
      logger.error("Go test output file is not readable: " .. result.output)
    end
    output = async.fn.readfile(result.output)
  elseif runner == "gotestsum" then
    if not context.test_output_json_filepath then
      logger.error("Gotestsum JSON output file path not provided")
    end
    local file_stat = vim.uv.fs_stat(context.test_output_json_filepath)
    if not file_stat or file_stat.size == 0 then -- check if file exists and is non-empty
      logger.error("Gotestsum JSON output file is missing or empty")
    end
    output = async.fn.readfile(context.test_output_json_filepath)
  end
  logger.debug({ "Runner '" .. runner .. "', raw output: ", output })

  --- The 'go list -json' output, converted into a lua table.
  -- local golist_output = context.golist_data

  --- @type GoTestEvent[]
  local gotest_output = lib.json.decode_from_table(output, true)

  -- Populate missing file results with aggregated data from child tests (bottom-up)
  results = M.populate_missing_file_results(tree, results)

  -- Populate missing directory results with aggregated data from descendant files (bottom-up)
  results = M.populate_missing_dir_results(tree, results)

  -- Register root node result in the cached results
  results[pos.id] = M.create_root_result(results[pos.id], result, gotest_output)

  -- Track missing results
  local missing = {}
  for _, node in tree:iter_nodes() do
    local node_pos = node:data()
    if results[node_pos.id] == nil then
      table.insert(missing, vim.inspect(node_pos.id))
    end
  end
  if #missing > 0 then
    if options.get().dev_notifications then
      logger.warn(
        "Test results not populated for the following Neotest positions:\n"
          .. table.concat(missing, "\n"),
        true
      )
    else
      logger.debug(
        "Test results not populated for the following Neotest positions:\n"
          .. table.concat(missing, "\n")
      )
    end
  end

  return results -- note that Neotest will only care about results[pos.id] returned here
end

--- Populate missing directory results with aggregated data from their descendant files.
--- Uses results-driven approach: extracts directory paths from existing results and creates
--- aggregated output for directories that lack results or have nil output.
--- Supports both direct file aggregation and hierarchical directory aggregation.
--- @param tree neotest.Tree The neotest tree structure (unused but kept for compatibility)
--- @param results table<string, neotest.Result> Current results
--- @return table<string, neotest.Result> Updated results with missing directory results populated
function M.populate_missing_dir_results(tree, results)
  -- Group file results by directory path
  local dir_to_files = {}

  -- Extract all file position IDs and group by directory path
  for pos_id, result in pairs(results) do
    -- Check if this is a file position (ends with .go but no "::")
    if pos_id:match("%.go$") and not pos_id:find("::") then
      -- Extract directory path using vim.fs.dirname
      local dir_path = vim.fs.dirname(pos_id)

      if dir_path and dir_path ~= "." then
        if not dir_to_files[dir_path] then
          dir_to_files[dir_path] = {}
        end
        table.insert(dir_to_files[dir_path], {
          pos_id = pos_id,
          result = result,
        })
      end
    end
  end

  -- Second pass: Add hierarchical directory aggregation
  -- Group existing directory results by their parent directories
  local dir_to_subdirs = {}

  for pos_id, result in pairs(results) do
    -- Check if this is a directory position (no .go and no ::)
    if not pos_id:match("%.go$") and not pos_id:find("::") then
      -- Extract parent directory path
      local parent_dir = vim.fs.dirname(pos_id)

      if parent_dir and parent_dir ~= "." and parent_dir ~= pos_id then
        if not dir_to_subdirs[parent_dir] then
          dir_to_subdirs[parent_dir] = {}
        end
        table.insert(dir_to_subdirs[parent_dir], {
          pos_id = pos_id,
          result = result,
        })
      end
    end
  end

  -- Create aggregated results for directories that need output
  for dir_path, file_entries in pairs(dir_to_files) do
    local dir_result = results[dir_path]
    local needs_aggregation = not dir_result or not dir_result.output

    if needs_aggregation then
      local dir_status = "passed"
      local all_errors = {}
      local combined_output = {}

      -- Add directory header
      table.insert(combined_output, "=== Directory: " .. dir_path .. " ===")

      -- Aggregate file results
      for _, entry in ipairs(file_entries) do
        local file_result = entry.result

        -- Aggregate status (failed > skipped > passed)
        if file_result.status == "failed" then
          dir_status = "failed"
        elseif file_result.status == "skipped" and dir_status ~= "failed" then
          dir_status = "skipped"
        end

        -- Collect errors
        if file_result.errors then
          vim.list_extend(all_errors, file_result.errors)
        end

        -- Collect output
        if file_result.output then
          local file_output_lines = async.fn.readfile(file_result.output)
          vim.list_extend(combined_output, file_output_lines)
        end
      end

      -- Only create directory result if we have files and actual output content
      if #file_entries > 0 and #combined_output > 1 then -- > 1 because we always add header
        -- Write combined output to file
        local dir_output_path = vim.fs.normalize(async.fn.tempname())
        async.fn.writefile(combined_output, dir_output_path)

        -- Create or update directory node result
        if dir_result then
          -- Update existing result with aggregated output
          dir_result.output = dir_output_path
          if #all_errors > 0 then
            dir_result.errors = all_errors
          end
        else
          -- Create new directory node result
          results[dir_path] = {
            status = dir_status,
            output = dir_output_path,
            errors = all_errors,
          }
        end
      end
    end
  end

  -- Process hierarchical directories (directories that aggregate from subdirectories)
  for parent_dir, subdir_entries in pairs(dir_to_subdirs) do
    local parent_result = results[parent_dir]
    local needs_aggregation = not parent_result or not parent_result.output

    if needs_aggregation then
      local parent_status = "passed"
      local all_errors = {}
      local combined_output = {}

      -- Add directory header
      table.insert(combined_output, "=== Directory: " .. parent_dir .. " ===")

      -- Aggregate subdirectory results
      for _, entry in ipairs(subdir_entries) do
        local subdir_result = entry.result

        -- Aggregate status (failed > skipped > passed)
        if subdir_result.status == "failed" then
          parent_status = "failed"
        elseif
          subdir_result.status == "skipped" and parent_status ~= "failed"
        then
          parent_status = "skipped"
        end

        -- Collect errors
        if subdir_result.errors then
          vim.list_extend(all_errors, subdir_result.errors)
        end

        -- Collect output from subdirectories
        if subdir_result.output then
          local subdir_output_lines = async.fn.readfile(subdir_result.output)
          vim.list_extend(combined_output, subdir_output_lines)
        end
      end

      -- Only create parent directory result if we have subdirectories and actual output content
      if #subdir_entries > 0 and #combined_output > 1 then -- > 1 because we always add header
        -- Write combined output to file
        local parent_output_path = vim.fs.normalize(async.fn.tempname())
        async.fn.writefile(combined_output, parent_output_path)

        -- Create or update parent directory node result
        if parent_result then
          -- Update existing result with aggregated output
          parent_result.output = parent_output_path
          if #all_errors > 0 then
            parent_result.errors = all_errors
          end
        else
          -- Create new parent directory node result
          results[parent_dir] = {
            status = parent_status,
            output = parent_output_path,
            errors = all_errors,
          }
        end
      end
    end
  end

  return results
end

--- Populate missing file results with aggregated data from their child tests.
--- Uses results-driven approach: extracts file paths from test position IDs and creates
--- aggregated output for files that lack results or have nil output.
--- @param tree neotest.Tree The neotest tree structure (unused but kept for compatibility)
--- @param results table<string, neotest.Result> Current results
--- @return table<string, neotest.Result> Updated results with missing file results populated
function M.populate_missing_file_results(tree, results)
  -- Group test results by file path
  local file_to_tests = {}

  -- Extract all test position IDs and group by file path
  for pos_id, result in pairs(results) do
    -- Check if this is a test position (contains "::")
    if pos_id:find("::") then
      -- Extract file path (everything before first "::")
      local file_path = pos_id:match("^([^:]+)")

      if file_path and file_path:match("%.go$") then
        if not file_to_tests[file_path] then
          file_to_tests[file_path] = {}
        end
        table.insert(file_to_tests[file_path], {
          pos_id = pos_id,
          result = result,
        })
      end
    end
  end

  -- Create aggregated results for files that need output
  for file_path, test_entries in pairs(file_to_tests) do
    local file_result = results[file_path]
    local needs_aggregation = not file_result or not file_result.output

    if needs_aggregation then
      local file_status = "passed"
      local all_errors = {}
      local combined_output = {}

      -- Add file header
      table.insert(combined_output, "=== File: " .. file_path .. " ===")

      -- Aggregate test results
      for _, entry in ipairs(test_entries) do
        local test_result = entry.result

        -- Aggregate status (failed > skipped > passed)
        if test_result.status == "failed" then
          file_status = "failed"
        elseif test_result.status == "skipped" and file_status ~= "failed" then
          file_status = "skipped"
        end

        -- Collect errors
        if test_result.errors then
          vim.list_extend(all_errors, test_result.errors)
        end

        -- Collect output
        if test_result.output then
          local test_output_lines = async.fn.readfile(test_result.output)
          vim.list_extend(combined_output, test_output_lines)
        end
      end

      -- Only create file result if we have tests and actual output content
      if #test_entries > 0 and #combined_output > 1 then -- > 1 because we always add header
        -- Write combined output to file
        local file_output_path = vim.fs.normalize(async.fn.tempname())
        async.fn.writefile(combined_output, file_output_path)

        -- Create or update file node result
        if file_result then
          -- Update existing result with aggregated output
          file_result.output = file_output_path
          if #all_errors > 0 then
            file_result.errors = all_errors
          end
        else
          -- Create new file node result
          results[file_path] = {
            status = file_status,
            output = file_output_path,
            errors = all_errors,
          }
        end
      end
    end
  end

  return results
end

--- Create the root result for the executed position based on test execution output.
--- Analyzes the overall test execution status and creates the primary result.
--- @param results_data table Previous results data (may be nil)
--- @param result neotest.StrategyResult Test execution result
--- @param gotest_output GoTestEvent[] Array of go test JSON events
--- @return neotest.Result The root result for the executed position
function M.create_root_result(results_data, result, gotest_output)
  local status = "passed"
  if result.code ~= 0 then
    status = "failed"
  end

  --- Set output from full test output
  -- Collect all output parts first
  local output_parts = {}
  for _, e in ipairs(gotest_output) do
    if e.Output then
      table.insert(output_parts, e.Output)
    end
  end

  -- Single-pass colorization of all parts
  local full_output = lib.colorize.colorize_parts(output_parts)

  local output = vim.fs.normalize(async.fn.tempname())
  async.fn.writefile(full_output, output)

  return {
    status = status,
    output = output,
    errors = results_data and results_data.errors or {},
  }
end

return M
