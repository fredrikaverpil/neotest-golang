local json = require("neotest-golang.lib.json")
local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")

local neotest_lib = require("neotest.lib")

local M = {}

--- Contstructor for new stream.
---@param json_filepath string|nil Path to the JSON output file
---@return function, function
function M.new(json_filepath)
  local stream_data = function() end
  local stop_stream = function() end
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
    return function()
      local json_lines = {}
      local results = {}
      if options.get().runner == "go" then
        local lines = data() -- capture from stdout
        for _, line in ipairs(lines) do
          json_lines =
            vim.list_extend(json_lines, json.decode_from_string(line))
        end
      elseif options.get().runner == "gotestsum" then
        local lines = stream_data() -- capture from stream
        for _, line in ipairs(lines) do
          json_lines = json.decode_from_string(line)
        end
      end

      for _, json_line in ipairs(json_lines) do
        -- started test detected
        if json_line.Action == "start" and json_line.Test ~= nil then
          vim.notify(vim.inspect(json_line))
          -- TODO: store ongoing test in lookup table
        end

        -- running test detected
        if json_line.Action == "output" and json_line.Test ~= nil then
          vim.notify(vim.inspect(json_line))
          -- TODO: store ongoing test in lookup table
        end

        -- passed test
        if json_line.Action == "pass" and json_line.Test ~= nil then
          vim.notify("PASS: " .. vim.inspect(json_line))
          -- TODO: map test/package to position id, add to results when all started tests have a status
        end
      end

      -- TODO: return results only if all ongoign tests have a status
      return results
    end
  end

  return stream, stop_stream
end

return M
