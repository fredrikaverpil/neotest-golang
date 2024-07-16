local M = {}

---@type neotest.Logger
local logger = require("neotest.logging")

local prefix = "[neotest-golang] "

-- NOTE: this level is not needed.
-- ---@param msg string
-- function M.trace(msg)
--   return logger.trace(prefix .. msg)
-- end

---Log the debug information.
---@param msg string
function M.debug(msg)
  logger.debug(prefix .. msg)
end

---Log the information.
---@param msg string
function M.info(msg)
  logger.info(prefix .. msg)
end

---Notify and log the warning.
---@param msg string
function M.warn(msg)
  vim.notify(msg, vim.log.levels.WARN)
  logger.warn(prefix .. msg)
end

---Notify, log and throw error.
---@param msg string
function M.error(msg)
  vim.notify(msg, vim.log.levels.ERROR)
  logger.error(prefix .. msg)
  error(msg)
end

function M.get_level()
  return logger._level
end

return M
