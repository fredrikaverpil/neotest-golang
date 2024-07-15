local M = {}

---@type neotest.Logger
local logger = require("neotest.logging")

local prefix = "[neotest-golang] "

---@param msg string
function M.trace(msg)
  return logger.trace(prefix .. msg)
end

---@param msg string
function M.debug(msg)
  logger.debug(prefix .. msg)
end

---@param msg string
function M.info(msg)
  logger.info(prefix .. msg)
end

---@param msg string
function M.warn(msg)
  vim.notify(msg, vim.log.levels.WARN)
  logger.warn(prefix .. msg)
end

---@param msg string
function M.error(msg)
  vim.notify(msg, vim.log.levels.ERROR)
  logger.error(prefix .. msg)
end

return M
