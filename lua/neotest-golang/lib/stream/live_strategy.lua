---Live streaming strategy for production use
local M = {}

---Create a live streaming data source for production gotestsum usage
---@param json_filepath string|nil Path to the JSON output file
---@return function stream_data Function that returns lines from live stream
---@return function stop_filestream Function to stop the stream
function M.create_stream(json_filepath)
  local neotest_lib = require("neotest.lib")
  local logger = require("neotest-golang.logging")
  local options = require("neotest-golang.options")

  if options.get().runner == "gotestsum" then
    if json_filepath ~= nil then
      logger.debug(
        "Setting up gotestsum live streaming for file: " .. json_filepath
      )
      neotest_lib.files.write(json_filepath, "")
      return neotest_lib.files.stream_lines(json_filepath)
    else
      logger.error("JSON filepath is required for gotestsum runner streaming")
      return function()
        return {}
      end, function() end
    end
  else
    -- For 'go' runner, streaming is handled differently (stdout-based)
    return function()
      return {}
    end, function() end
  end
end

return M
