---Live streaming strategy for production use
local M = {}

---Create a live streaming data source for production gotestsum usage
---@param json_filepath string|nil Path to the JSON output file
---@return function stream_data Function that returns lines from live stream
---@return function stop_filestream Function to stop the stream
function M.create_stream(json_filepath)
  local neotest_lib = require("neotest.lib")
  local logger = require("neotest-golang.lib.logging")
  local options = require("neotest-golang.options")

  if options.get().runner == "gotestsum" then
    if json_filepath ~= nil then
      logger.debug(
        "Setting up gotestsum live streaming for file: " .. json_filepath
      )

      -- Check file path before writing
      local pre_write_stat = vim.uv.fs_stat(json_filepath)
      logger.debug({
        "JSON file pre-write check",
        filepath = json_filepath,
        exists_before_write = pre_write_stat ~= nil,
        timestamp = os.time(),
        process_id = vim.fn.getpid(),
      })

      -- Initialize empty JSON file for gotestsum streaming
      logger.debug(
        "Writing empty content to initialize JSON file: " .. json_filepath
      )
      neotest_lib.files.write(json_filepath, "")

      -- Verify file was created successfully
      local post_write_stat = vim.uv.fs_stat(json_filepath)
      logger.debug({
        "JSON file post-write verification",
        filepath = json_filepath,
        exists_after_write = post_write_stat ~= nil,
        file_size = post_write_stat and post_write_stat.size or "unknown",
        file_mode = post_write_stat and post_write_stat.mode or "unknown",
        timestamp = os.time(),
      })

      if not post_write_stat then
        logger.error(
          "Failed to create JSON file for streaming: " .. json_filepath
        )
      else
        logger.debug("Successfully initialized JSON file for streaming")
      end

      logger.debug("Starting neotest file stream for: " .. json_filepath)
      return neotest_lib.files.stream_lines(json_filepath)
    else
      local error_msg =
        "JSON filepath is required for gotestsum runner streaming"
      logger.error(error_msg)
      -- Return functions that indicate the error condition rather than silently failing
      return function()
        logger.warn("Streaming disabled: " .. error_msg)
        return {}
      end, function()
        logger.debug(
          "Stream stop called but streaming was disabled due to missing JSON filepath"
        )
      end
    end
  else
    -- For 'go' runner, streaming is handled differently (stdout-based)
    return function()
      return {}
    end, function() end
  end
end

return M
