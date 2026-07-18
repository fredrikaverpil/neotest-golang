---Test streaming strategy for integration tests that read completed files
local M = {}
local file = require("neotest-golang.lib.file")

---Create a test streaming data source for integration tests
---This strategy reads from completed files rather than live streaming
---Integration tests run synchronously, so we use synchronous vim.uv file I/O.
---@param json_filepath string|nil Path to the JSON output file
---@return function stream_data Function that returns lines from completed file
---@return function stop_filestream Function to stop the stream (no-op for tests)
function M.create_stream(json_filepath)
  local logger = require("neotest-golang.lib.logging")

  local stream_data = function()
    if not json_filepath then
      return {}
    end

    local file_stat = vim.uv.fs_stat(json_filepath)
    if file_stat and file_stat.size > 0 then
      local file_lines = file.read_lines(json_filepath)
      logger.debug(
        "Test strategy: read " .. #file_lines .. " lines from gotestsum file"
      )
      return file_lines
    else
      logger.debug("Test strategy: gotestsum file not ready yet")
      return {}
    end
  end

  local stop_filestream = function()
    -- No-op for integration tests since file is already complete
  end

  return stream_data, stop_filestream
end

return M
