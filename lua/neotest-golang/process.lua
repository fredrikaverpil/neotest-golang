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

  ---@type table<string, neotest.Result>
  local results = require("neotest-golang.lib.stream").cached_results -- TODO: fix circular dependency
  results[pos.id] = M.node_results(result, gotest_output)

  -- Log tests wich were not populated into the results
  for _, node in tree:iter_nodes() do
    local pos_ = node:data()
    if results[pos_.id] == nil then
      logger.debug("Test data not populated for: " .. vim.inspect(pos.id))
    end
  end

  return results
end

--- Process a single event from the test output.
--- @param accum table Accumulated test data.
--- @param e table The event data.
function M.process_event(tree, golist_data, accum, e)
  if e.Package then
    local id = e.Package
    accum = M.process_package(tree, golist_data, accum, e, id)
  end

  if e.Package and e.Test then
    local id = e.Package .. "::" .. e.Test
    accum = M.process_test(tree, golist_data, accum, e, id)
  end

  return accum
end

function M.register_output(accum, e, id)
  if e.Output then
    accum[id].output = accum[id].output .. M.colorizer(e.Output)
    accum = M.find_errors(accum, id)
  end
  return accum
end

function M.find_errors(accum, id)
  local outputs = vim.split(accum[id].output, "\n", { trimempty = true })
  for _, output in ipairs(outputs) do
    -- search for error message and line number
    local matched_line_number = string.match(output, "go:(%d+):")
    if matched_line_number ~= nil then
      local line_number = tonumber(matched_line_number)
      local message = string.match(output, "go:%d+: (.*)")
      if line_number ~= nil and message ~= nil then
        table.insert(accum[id].errors, {
          line = line_number - 1, -- neovim lines are 0-indexed
          message = message,
        })
      end
    end
  end
  return accum
end

function M.process_package(tree, golist_data, accum, e, id)
  -- Indicate package started/running.
  if not accum[id] and (e.Action == "start" or e.Action == "run") then
    accum[id] = { status = "running", output = "", errors = {} }
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

function M.process_test(tree, golist_data, accum, e, id)
  -- Indicate test started/running.
  if not accum[id] and e.Action == "run" then
    accum[id] = { status = "running", output = "", errors = {} }
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
    local pattern =
      lib.convert.to_test_position_id_pattern(golist_data, e.Package, e.Test)
    if pattern then
      local pos_id = M.find_position_id_for_test(tree, pattern)
      if pos_id then
        accum[id].position_id = pos_id
      else
        -- TODO: it would be better to store these in a list instead.
        logger.debug(
          "Unable to find position id for passed test: "
            .. e.Package
            .. "::"
            .. e.Test
        )
      end
    else
      logger.error(
        "Could not find position id pattern for test: "
          .. e.Test
          .. " in package: "
          .. e.Package
      )
    end
  end
  return accum
end

--- Process internal test data.
---@param accum table The accumulated test data to process -- TODO: add proper type
function M.process_accumulated_test_data(accum)
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

--- Opportunity below to analyze based on full test output.
function M.node_results(result, gotest_output)
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

  return { status = status, output = output }
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

-- Find position id in neotest tree, given pattern.
---@param tree neotest.Tree The Neotest tree structure
---@param test_pattern string The pattern to match against position ids
---@return string|nil The position id, if any.
function M.find_position_id_for_test(tree, test_pattern)
  -- Search the tree for matching position id
  for _, node in tree:iter_nodes() do
    --- @type neotest.Position
    local pos = node:data()

    -- Test pattern:
    -- {
    --   id = '/Users/fredrik/code/public/someproject/internal/foo/bar/baz_test.go::TestName::"SubTestName"',
    --   name = '"SubTestName"',
    --   path = "/Users/fredrik/code/public/someproject/internal/foo/bar/baz_test.go",
    --   range = { 11, 1, 28, 3 },
    --   type = "test"
    -- }
    if pos.id:match(test_pattern) and pos.type == "test" then
      return pos.id
    end

    -- Namespace pattern:
    -- (same as test pattern?)

    -- File pattern:
    -- {
    --   id = "/Users/fredrik/code/public/someproject/internal/foo/bar/baz_test.go",
    --   name = "baz_test.go",
    --   path = "/Users/fredrik/code/public/someproject/internal/foo/bar/baz_test.go",
    --   range = { 0, 0, 30, 0 },
    --   type = "file"
    -- }
    -- local file_pattern = pattern:match("^(.-)::")
    -- if pos.id:match(file_pattern) and pos.type == "file" then
    --   return pos.id
    -- end

    -- Dir pattern:
    -- {
    --   id = "/Users/fredrik/code/public/someproject/internal/foo/bar",
    --   name = "bar",
    --   path = "/Users/fredrik/code/public/someproject/internal/foo/bar",
    --   type = "dir"
    -- }
    --   local file_path = pattern:match("^(.-)::")
    --   local dir_pattern = file_path and file_path:match("(.+)/[^/]+$")
    --   if dir_pattern and pos.id:match(dir_pattern) and pos.type == "dir" then
    --     return pos.id
    --   end
  end
end

return M
