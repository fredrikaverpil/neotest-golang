local convert = require("neotest-golang.lib.convert")
local json = require("neotest-golang.lib.json")
local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")

local neotest_lib = require("neotest.lib")

local M = {}

--- Convert to internal and unique test id for lookup.
local function to_test_id(package_name, test_name)
  return package_name .. "::" .. test_name
end

--- Contstructor for new stream.
--- @param golist_data table Golist data containing package information
---@param json_filepath string|nil Path to the JSON output file
---@return function, function
function M.new(tree, golist_data, json_filepath)
  -- vim.notify(vim.inspect("New stream!"))

  M.accumulated_test_data = {} -- reset
  local stream_data = function() end -- no-op
  local stop_stream = function() end -- no-op
  if options.get().runner == "gotestsum" then
    if json_filepath ~= nil then
      neotest_lib.files.write(json_filepath, "") -- ensure the file exists
      stream_data, stop_stream = neotest_lib.files.stream_lines(json_filepath)
    else
      logger.error("JSON filepath is required for gotestsum runner streaming")
    end
  end

  --- Stream function.
  ---@param data function A function that returns a table of strings, each representing a line of JSON output.
  local function stream(data)
    local tree = tree
    local golist_data = golist_data
    local json_lines = {}
    local accum = {}

    ---@type table<string, neotest.Result>
    local results = {}

    return function()
      local lines = {}
      if options.get().runner == "go" then
        lines = data() -- capture from stdout
      elseif options.get().runner == "gotestsum" then
        lines = stream_data() -- capture from stream
      end

      for _, line in ipairs(lines) do
        json_lines = vim.list_extend(json_lines, json.decode_from_string(line))
        for _, json_line in ipairs(json_lines) do
          accum = M.process_event(tree, golist_data, accum, json_line)
        end
      end

      for _, test_data in pairs(accum) do
        if test_data.status == "passed" then
          results[test_data.position_id] = {
            status = test_data.status, -- passed/failed/skipped
            output = test_data.output,
            -- TODO: add short
            -- TODO: add errors
          }
        end
      end

      -- TODO: only return a result when a test has a status (pass/fail/skip), otherwise return {}
      return results
    end
  end

  return stream, stop_stream
end

--- Process a single event from the test output.
--- @param accum table Accumulated test data.
--- @param e table The event data.
function M.process_event(tree, golist_data, accum, e)
  -- TODO: do we want to do something with 'start' status?

  -- Indicate test started/running.
  if e.Action == "run" and e.Test ~= nil then
    local id = to_test_id(e.Package, e.Test)
    accum[id] = { status = "running", output = "" }
    if e.Output ~= nil then
      accum[id].output = e.Output
    end
  end

  -- Record output.
  if e.Action == "output" and e.Test ~= nil and e.Output ~= nil then
    local id = to_test_id(e.Package, e.Test)
    accum[id].output = accum[id].output .. "\n" .. e.Output
  end

  -- Passed test.
  if e.Action == "pass" and e.Test ~= nil then
    local id = to_test_id(e.Package, e.Test)
    accum[id].status = "passed"
    if e.Output ~= nil then
      accum[id].output = accum[id].output .. "\n" .. e.Output
    end

    local pattern =
      convert.to_position_id_pattern(golist_data, e.Package, e.Test)
    accum[id].position_id = convert.to_position_id(tree, pattern)
  end

  return accum
end

return M
