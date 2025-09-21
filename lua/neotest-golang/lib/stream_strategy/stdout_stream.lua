---Stdout-based streaming strategy for runners that output to stdout
local logger = require("neotest-golang.logging")

local M = {}

---Create a stdout-based streaming data source
---This is a no-op strategy since go test outputs to stdout and neotest handles that
---@param exec_context table|nil Execution context (unused for stdout streaming)
---@return function stream_data Function that returns empty data (no-op)
---@return function stop_filestream Function to stop the stream (no-op)
function M.create_stream(exec_context)
  logger.debug("Using stdout streaming strategy")

  -- Return no-op functions since stdout is handled by neotest directly
  local stream_data = function()
    return {}
  end

  local stop_filestream = function()
    -- No-op for stdout streaming
  end

  return stream_data, stop_filestream
end

return M
