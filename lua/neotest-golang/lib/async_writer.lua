local async = require("neotest.async")
local logger = require("neotest-golang.logging")

local M = {}

---@type table<string, boolean> Track which files are currently being written
M._writing = {}

---@type table<string, table> Track pending write operations
M._pending_writes = {}

---Asynchronously write content to a file with proper queueing
---@param filepath string The path where content should be written
---@param content table The lines to write to the file
---@param callback function|nil Optional callback when write completes
function M.write_async(filepath, content, callback)
  -- If already writing to this file, queue the operation
  if M._writing[filepath] then
    logger.debug("Queueing write operation for: " .. filepath)
    M._pending_writes[filepath] = { content = content, callback = callback }
    return
  end

  -- Mark as being written
  M._writing[filepath] = true
  logger.debug("Starting async write for: " .. filepath)

  -- Perform the async write
  async.run(function()
    local success, err = pcall(function()
      async.fn.writefile(content, filepath)
    end)

    if not success then
      logger.error("Failed to write file " .. filepath .. ": " .. tostring(err))
    else
      logger.debug("Successfully wrote file: " .. filepath)
    end

    -- Call completion callback if provided
    if callback then
      callback(success, err)
    end

    -- Mark as no longer being written
    M._writing[filepath] = nil

    -- Process any pending writes for this file
    local pending = M._pending_writes[filepath]
    if pending then
      M._pending_writes[filepath] = nil
      logger.debug("Processing pending write for: " .. filepath)
      M.write_async(filepath, pending.content, pending.callback)
    end
  end)
end

---Wait for all pending write operations to complete
---This is useful during finalization to ensure all files are written
function M.wait_for_completion()
  local max_wait = 100 -- Maximum iterations to wait
  local wait_count = 0

  while
    (vim.tbl_count(M._writing) > 0 or vim.tbl_count(M._pending_writes) > 0)
    and wait_count < max_wait
  do
    async.util.sleep(10) -- Wait 10ms
    wait_count = wait_count + 1
  end

  if wait_count >= max_wait then
    logger.warn("Timeout waiting for async writes to complete")
  else
    logger.debug(
      "All async writes completed after " .. (wait_count * 10) .. "ms"
    )
  end
end

---Get the current status of async operations (for debugging)
---@return table Status information
function M.get_status()
  return {
    writing_count = vim.tbl_count(M._writing),
    pending_count = vim.tbl_count(M._pending_writes),
    writing_files = vim.tbl_keys(M._writing),
    pending_files = vim.tbl_keys(M._pending_writes),
  }
end

return M
