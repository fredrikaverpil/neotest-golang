--- This file is centered around the parsing/processing of test execution output
--- and assembling of the final results to hand back over to Neotest.

local async = require("neotest.async")

local lib = require("neotest-golang.lib")
local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")

--- @class RunspecContext
--- @field pos_id string Neotest tree position id.
--- @field golist_data table<string, string> The 'go list' JSON data (lua table).
--- @field errors? table<string> Non-gotest errors to show in the final output.
--- @field is_dap_active boolean? If true, parsing of test output will occur.
--- @field test_output_json_filepath? string Gotestsum JSON filepath.
--- @field stop_stream fun() Stops the stream of test output.

--- @alias TestAccumulator table<string, { pos_id: string|nil, status: neotest.ResultStatus, output: string, errors: table[], position_id?: string, output_path?: string }>

--- @class GoTestEvent
--- @field Time? string ISO 8601 timestamp when the event occurred
--- @field Action "run"|"pause"|"cont"|"pass"|"bench"|"fail"|"output"|"skip"|"start" Test action
--- @field Package? string Package name being tested
--- @field Test? string Test name (present when Action relates to a specific test)
--- @field Elapsed? number Time elapsed in seconds
--- @field Output? string Output text (present when Action is "output")

local M = {}

--- Process the results from the test command.
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

  spec.context.stop_stream()

  --- Final Neotest results, the way Neotest wants it returned.
  --- @type table<string, neotest.Result>
  local neotest_result = {}

  if context.is_dap_active then
    -- return early if test result processing is not desired.
    neotest_result[context.pos_id] = {
      status = "skipped",
    }
    return neotest_result
  end

  --- The runner to use for running tests.
  --- @type string
  local runner = options.get().runner

  --- The raw output from the test command.
  --- @type table<string>
  local raw_output = async.fn.readfile(result.output)
  --- @type table<string>
  local runner_raw_output = {}
  if runner == "go" then
    runner_raw_output = raw_output
  elseif runner == "gotestsum" then
    if context.test_output_json_filepath == nil then
      logger.error("Gotestsum JSON output file not found.")
      return neotest_result
    end
    runner_raw_output = async.fn.readfile(context.test_output_json_filepath)
  end
  logger.debug({ "Runner '" .. runner .. "', raw output: ", runner_raw_output })

  --- The 'go list -json' output, converted into a lua table.
  -- local golist_output = context.golist_data

  --- Go test output.
  --- @type table
  local gotest_output = lib.json.decode_from_table(runner_raw_output, true)

  -- Re-register cached results.
  ---@type table<string, neotest.Result>
  local results = require("neotest-golang.lib.stream").cached_results -- TODO: fix circular dependency
  require("neotest-golang.lib.stream").cached_results = {} -- clear cache
  results[pos.id] = M.node_results(results[pos.id], result, gotest_output) -- register root node result

  -- Log tests wich were not populated into the results
  for _, node in tree:iter_nodes() do
    local pos_ = node:data()
    if results[pos_.id] == nil then
      logger.debug("Test data not populated for: " .. vim.inspect(pos_.id))
    end
  end

  return results
end

--- Process a single event from the test output.
--- @param tree neotest.Tree The neotest tree structure
--- @param golist_data table The 'go list -json' output
--- @param accum TestAccumulator Accumulated test data.
--- @param e GoTestEvent The event data.
--- @param position_lookup table<string, string> Position lookup table for O(1) mapping
--- @return TestAccumulator
function M.process_event(tree, golist_data, accum, e, position_lookup)
  if e.Package then
    local id = e.Package
    accum = M.process_package(tree, golist_data, accum, e, id, position_lookup)
  end

  if e.Package and e.Test then
    local id = e.Package .. "::" .. e.Test
    accum = M.process_test(tree, golist_data, accum, e, id, position_lookup)
  end

  return accum
end

--- Register output for a test/package
--- @param accum TestAccumulator
--- @param e GoTestEvent Event data
--- @param id string Test/package ID
--- @return TestAccumulator
function M.register_output(accum, e, id)
  if e.Output then
    accum = M.register_diagnostics(accum, id, e.Output)
    local colorized_output = M.colorizer(e.Output)
    accum[id].output = accum[id].output .. colorized_output
  end
  return accum
end

--- Register diagnostics for a test/package
--- @param accum TestAccumulator
--- @param id string Test/package ID (may be pos_id or synthetic ID)
--- @param event_output string Event output text
--- @return TestAccumulator
function M.register_diagnostics(accum, id, event_output)
  local lines = vim.split(event_output, "\n", { trimempty = true })

  -- Extract the test file's filename if the ID is a pos_id
  local test_filename = M.extract_filename_from_pos_id(accum[id].pos_id)

  for _, line in ipairs(lines) do
    -- Use optimized single-pass pattern matching
    local diagnostic = lib.patterns.parse_diagnostic_line(line)
    if diagnostic then
      -- Filter diagnostics by filename if we have both filenames
      local should_include_diagnostic = true
      if test_filename and diagnostic.filename then
        -- Only include diagnostic if it belongs to the test file
        should_include_diagnostic = (diagnostic.filename == test_filename)
        if not should_include_diagnostic then
          logger.debug(
            "Filtering out diagnostic from "
              .. diagnostic.filename
              .. " (test file: "
              .. test_filename
              .. "): "
              .. diagnostic.message
          )
        end
      elseif not test_filename then
        -- If we can't determine the test filename (synthetic ID), log but include all diagnostics
        logger.debug(
          "Cannot filter diagnostics for synthetic ID: "
            .. id
            .. ", including diagnostic from "
            .. (diagnostic.filename or "unknown")
        )
      end

      if should_include_diagnostic then
        -- Check for duplicates before adding
        local error_exists = false
        for _, existing_error in ipairs(accum[id].errors) do
          if
            existing_error.line == diagnostic.line_number - 1
            and existing_error.message == diagnostic.message
          then
            error_exists = true
            break
          end
        end

        if not error_exists then
          table.insert(accum[id].errors, {
            line = diagnostic.line_number - 1,
            message = diagnostic.message,
            severity = diagnostic.severity,
          })
        end
      end
    end
  end
  return accum
end

--- Process package events
--- @param tree neotest.Tree The neotest tree structure
--- @param golist_data table The 'go list -json' output
--- @param accum TestAccumulator Accumulated test data
--- @param e GoTestEvent The event data
--- @param id string Package ID
--- @param position_lookup table<string, string> Position lookup table for O(1) mapping
--- @return TestAccumulator
function M.process_package(tree, golist_data, accum, e, id, position_lookup)
  -- Indicate package started/running.
  if not accum[id] and (e.Action == "start" or e.Action == "run") then
    local pos_id = position_lookup[id]
    accum[id] = {
      pos_id = pos_id, -- could be nil
      status = "running",
      output = "",
      errors = {},
    }
    accum = M.register_output(accum, e, id)
  end

  -- Record output for package.
  if accum[e.Package].status == "running" and e.Action == "output" then
    accum = M.register_output(accum, e, id)
  end

  -- Register package results.
  if
    accum[e.Package].status == "running"
    and (e.Action == "pass" or e.Action == "fail" or e.Action == "skip")
  then
    if e.Action == "pass" then
      accum[id].status = "passed"
    elseif e.Action == "fail" then
      accum[id].status = "failed"
    else
      accum[id].status = "skipped"
    end
    accum[id].position_id =
      lib.convert.to_dir_position_id(golist_data, e.Package)
    accum = M.register_output(accum, e, id)
    accum[id].output_path = vim.fs.normalize(async.fn.tempname())
  end
  return accum
end

--- Process test events
--- @param tree neotest.Tree The neotest tree structure
--- @param golist_data table The 'go list -json' output
--- @param accum TestAccumulator Accumulated test data
--- @param e GoTestEvent The event data
--- @param id string Test ID
--- @param position_lookup table<string, string> Position lookup table for O(1) mapping
--- @return TestAccumulator
function M.process_test(tree, golist_data, accum, e, id, position_lookup)
  -- Indicate test started/running.
  if not accum[id] and e.Action == "run" then
    local pos_id = position_lookup[id]
    accum[id] = {
      pos_id = pos_id, -- could be nil if test was not found by AST parsing
      status = "running",
      output = "",
      errors = {},
    }
    accum = M.register_output(accum, e, id)
  end

  -- Record output for test.
  if accum[id].status == "running" and e.Action == "output" then
    accum = M.register_output(accum, e, id)
  end

  -- Register test results.
  if
    accum[id].status == "running"
    and (e.Action == "pass" or e.Action == "fail" or e.Action == "skip")
  then
    if e.Action == "pass" then
      accum[id].status = "passed"
    elseif e.Action == "fail" then
      accum[id].status = "failed"
    else
      accum[id].status = "skipped"
    end
    accum = M.register_output(accum, e, id)
    accum[id].output_path = vim.fs.normalize(async.fn.tempname())

    local pos_id =
      lib.convert.get_position_id(position_lookup, e.Package, e.Test)
    if pos_id then
      accum[id].position_id = pos_id
    else
      logger.debug(
        "Unable to find position id for test: " .. e.Package .. "::" .. e.Test
      )
    end
  end
  return accum
end

--- Process internal test data.
---@param accum TestAccumulator The accumulated test data to process
---@return table<string, neotest.Result>
function M.make_results(accum)
  ---@type table<string, neotest.Result>
  local results = {}

  for _, test_data in pairs(accum) do
    if test_data.position_id ~= nil then
      local uv = vim.loop
      local stat = uv.fs_stat(test_data.output_path)
      if not stat then
        -- does not exist, let's write it
        local o =
          vim.split(M.colorizer(test_data.output), "\n", { trimempty = true })
        async.fn.writefile(o, test_data.output_path)
      end

      results[test_data.position_id] = {
        status = test_data.status,
        output = test_data.output_path,
        errors = test_data.errors,
        -- TODO: add short
      }
    end

    -- if pos.id == test_data.position_id and result.code ~= 0 then
    --   results[test_data.position_id].status = "failed"
    -- end
  end

  return results
end

--- Populate file nodes with aggregated results from their child tests
--- @param tree neotest.Tree The neotest tree structure
--- @param results table<string, neotest.Result> Current results
--- @return table<string, neotest.Result> Updated results with file node data
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
        table.insert(combined_output, "")

        for _, child_result in ipairs(child_tests) do
          if child_result.output then
            -- Read child test output
            local child_output_lines = async.fn.readfile(child_result.output)
            vim.list_extend(combined_output, child_output_lines)
            table.insert(combined_output, "") -- separator
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
  ---@type string[]
  local full_output = {}
  for _, e in ipairs(gotest_output) do
    if e.Output then
      local lines = vim.split(M.colorizer(e.Output), "\n", { trimempty = true })
      for _, line in ipairs(lines) do
        table.insert(full_output, line)
      end
    end
  end

  local output = vim.fs.normalize(async.fn.tempname())
  async.fn.writefile(full_output, output)

  return {
    status = status,
    output = output,
    errors = results_data and results_data.errors or {},
  }
end

--- Colorize the line of text given.
--- @param text string The line of text to parse for colorization
--- @return string The colorized line of text (if colorization is enabled)
function M.colorizer(text)
  if not options.get().colorize_test_output == true or not text then
    return text
  end

  local original_text = text
  local trailing_newline = ""

  -- Check for and strip trailing newline to ensure reset code is before it
  if text:sub(-1) == "\n" then
    trailing_newline = "\n"
    text = text:sub(1, -2) -- Remove the trailing newline for processing
  end

  local color_applied = false

  if string.find(text, "FAIL") then
    text = text:gsub("^", "[31m") .. "[0m" -- red
    color_applied = true
  elseif string.find(text, "PASS") then
    text = text:gsub("^", "[32m") .. "[0m" -- green
    color_applied = true
  elseif string.find(text, "WARN") then
    text = text:gsub("^", "[33m") .. "[0m" -- yellow
    color_applied = true
  elseif string.find(text, "RUN") then
    text = text:gsub("^", "[34m") .. "[0m" -- blue
    color_applied = true
  elseif string.find(text, "SKIP") then
    text = text:gsub("^", "[35m") .. "[0m" -- purple
    color_applied = true
  end

  -- Re-append the trailing newline if it was originally present and color was applied
  if color_applied then
    return text .. trailing_newline
  else
    -- If no color was applied, return the original text with its newline intact
    return original_text
  end
end

--- Extract the filename from a neotest position ID
--- @param pos_id string Position ID like "/path/to/file.go::TestName" or synthetic ID like "github.com/pkg::TestName"
--- @return string|nil Filename like "file.go" or nil if not a file path
function M.extract_filename_from_pos_id(pos_id)
  if not pos_id then
    return nil
  end

  -- Check if it looks like a file path (contains "/" and ends with ".go")
  local file_path = pos_id:match("^([^:]+)")
  if file_path and file_path:match("%.go$") and file_path:match("/") then
    -- Extract just the filename from the full path
    return file_path:match("([^/]+)$")
  end

  return nil
end

return M
