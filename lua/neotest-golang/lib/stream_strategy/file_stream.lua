---File-based streaming strategy for runners that output to files
local logger = require("neotest-golang.logging")

local M = {}

---Create a file-based streaming data source
---Supports both live streaming (for production) and test mode (for integration tests)
---@param output_file string|nil Path to the runner output file
---@param test_mode boolean|nil Whether to use test mode (synchronous file reading)
---@return function stream_data Function that returns lines from file stream
---@return function stop_filestream Function to stop the stream
function M.create_stream(output_file, test_mode)
  if not output_file then
    local error_msg = "Runner output file is required for file streaming"
    logger.error(error_msg)
    -- Return functions that indicate the error condition rather than silently failing
    return function()
      logger.warn("Streaming disabled: " .. error_msg)
      return {}
    end, function()
      logger.debug(
        "Stream stop called but streaming was disabled due to missing runner output file"
      )
    end
  end

  if test_mode then
    -- Test mode: synchronous file reading for integration tests
    logger.debug(
      "Setting up test mode file streaming for file: " .. output_file
    )

    local stream_data = function()
      local file_stat = vim.uv.fs_stat(output_file)
      if file_stat and file_stat.size > 0 then
        -- Use synchronous file reading since integration tests run in sync context
        local file_lines = vim.fn.readfile(output_file)
        logger.debug(
          "Test mode: read " .. #file_lines .. " lines from runner output file"
        )
        return file_lines
      else
        logger.debug("Test mode: runner output file not ready yet")
        return {}
      end
    end

    local stop_filestream = function()
      -- No-op for integration tests since file is already complete
    end

    return stream_data, stop_filestream
  else
    -- Live mode: asynchronous file streaming for production
    logger.debug("Setting up live file streaming for file: " .. output_file)
    local neotest_lib = require("neotest.lib")
    neotest_lib.files.write(output_file, "")
    return neotest_lib.files.stream_lines(output_file)
  end
end

return M
