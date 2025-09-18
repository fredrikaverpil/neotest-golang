--- This file is centered around the parsing/processing of test execution output
--- and assembling of the final results to hand back over to Neotest.

local async = require("neotest.async")

local lib = require("neotest-golang.lib")
local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")

local M = {}

--- @class RunspecContext
--- @field pos_id string Neotest tree position id.
--- @field golist_data table<string, string> The 'go list' JSON data (lua table).
--- @field errors? table<string> Non-gotest errors to show in the final output.
--- @field is_dap_active boolean? If true, parsing of test output will occur.
--- @field test_output_json_filepath? string Gotestsum JSON filepath.
--- @field stop_filestream fun() Stops the stream of test output.

--- Process the complete test output from the test command.
--- @param spec neotest.RunSpec
--- @param result neotest.StrategyResult
--- @param tree neotest.Tree
--- @return table<string, neotest.Result>
function M.test_results(spec, result, tree)
  -- TODO: refactor this function into function calls; return_early, process_test_results, override_test_results.

  --- @type RunspecContext
  local context = spec.context

  --- @type neotest.Position
  local pos = tree:data()

  -- Stop streaming first to ensure all results are cached
  spec.context.stop_filestream()

  -- Get final cached results after streaming is complete
  ---@type table<string, neotest.Result>
  local results = lib.stream.get_final_cached_results()

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

  -- Register root node result in the cached results
  results[pos.id] = M.node_results(results[pos.id], result, gotest_output)

  -- Populate file nodes with aggregated results
  results = M.populate_file_nodes(tree, results)

  -- Track missing results
  local missing = {}
  for _, node in tree:iter_nodes() do
    local node_pos = node:data()
    if results[node_pos.id] == nil then
      table.insert(missing, vim.inspect(node_pos.id))
    end
  end
  if #missing > 0 then
    if options.get().warn_test_results_missing then
      logger.warn(
        "Test results not populated for the following Neotest positions:\n"
          .. table.concat(missing, "\n")
      )
    else
      logger.debug(
        "Test results not populated for the following Neotest positions:\n"
          .. table.concat(missing, "\n")
      )
    end
  end

  return results
end

--- Populate file nodes with aggregated results from their child tests
--- @param tree neotest.Tree The neotest tree structure
--- @param results table<string, neotest.Result> Current results
--- @return table<string, neotest.Result> Updated results with file node data
-- NOTE: this is intense, so cannot be part of streaming hot path.
function M.populate_file_nodes(tree, results)
  for _, node in tree:iter_nodes() do
    local pos = node:data()

    if pos.type == "file" and not results[pos.id] then
      -- Collect all child test results for this file
      local child_tests = {}
      local file_status = "passed"
      local has_tests = false
      local all_errors = {}

      for _, child_node in tree:iter_nodes() do
        local child_pos = child_node:data()
        local child_result = results[child_pos.id]

        -- Check if this test belongs to this file
        if
          child_pos.type == "test"
          and child_result
          and child_pos.path == pos.path
        then
          has_tests = true
          table.insert(child_tests, child_result)

          -- Aggregate status (failed > skipped > passed)
          if child_result.status == "failed" then
            file_status = "failed"
          elseif
            child_result.status == "skipped" and file_status ~= "failed"
          then
            file_status = "skipped"
          end

          -- Collect errors
          if child_result.errors then
            vim.list_extend(all_errors, child_result.errors)
          end
        end
      end

      if has_tests then
        -- Create combined output file
        local combined_output = {}
        table.insert(combined_output, "=== File: " .. pos.path .. " ===")

        for _, child_result in ipairs(child_tests) do
          if child_result.output then
            -- Read child test output
            local child_output_lines = async.fn.readfile(child_result.output)
            vim.list_extend(combined_output, child_output_lines)
          end
        end

        -- Write combined output to file
        local file_output_path = vim.fs.normalize(async.fn.tempname())
        async.fn.writefile(combined_output, file_output_path)

        -- Create file node result
        results[pos.id] = {
          status = file_status,
          output = file_output_path,
          errors = all_errors,
        }

        logger.debug(
          "Populated file node "
            .. pos.id
            .. " with status: "
            .. file_status
            .. " from "
            .. #child_tests
            .. " child tests"
        )
      end
    end
  end

  return results
end

--- Opportunity below to analyze based on full test output.
--- @param results_data table Previous results data
--- @param result neotest.StrategyResult Test execution result
--- @param gotest_output GoTestEvent[] Array of go test JSON events
--- @return neotest.Result
function M.node_results(results_data, result, gotest_output)
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
