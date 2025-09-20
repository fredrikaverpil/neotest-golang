local M = {}

local logger = nil

local function get_logger()
  local options = require("neotest-golang.options")

  if logger == nil then
    ---@type neotest.Logger
    logger = require("neotest.logging").new(
      "neotest-golang",
      { level = options.get().log_level }
    )
  end

  return logger
end

local function clean_output(str)
  -- Replace escaped newlines and tabs with spaces
  str = str:gsub("[\n\t]", " ")
  -- Collapse multiple spaces into one
  str = str:gsub("%s+", " ")
  return str
end

---@param input any
---@return string
local function handle_input(input)
  if type(input) == "string" then
    return clean_output(input)
  elseif type(input) == "table" then
    local result = ""
    for _, v in ipairs(input) do
      if type(v) == "table" then
        result = result .. vim.inspect(v) .. " "
      elseif type(v) == "string" then
        result = result .. clean_output(v) .. " "
      else
        result = result .. tostring(v) .. " "
      end
    end
    return result:sub(1, -2) -- Remove trailing space
  else
    return tostring(input)
  end
end

---Log the trace information.
---@param msg string|table
function M.trace(msg)
  if M.get_level() > vim.log.levels.TRACE then
    return
  end
  if type(msg) ~= "string" then
    msg = handle_input(msg)
  end
  get_logger().trace(msg)
end

---Log the debug information.
---@param msg string|table
function M.debug(msg)
  if M.get_level() > vim.log.levels.DEBUG then
    return
  end
  if type(msg) ~= "string" then
    msg = handle_input(msg)
  end
  get_logger().debug(msg)
end

---Log the information.
---@param msg string|table
function M.info(msg)
  if M.get_level() > vim.log.levels.INFO then
    return
  end
  if type(msg) ~= "string" then
    msg = handle_input(msg)
  end
  get_logger().info(msg)
end

---Log the warning.
--- WARNING: notifying causes issues when logging from async context.
---@param msg string|table
---@param notify boolean|nil Whether to also notify the user
function M.warn(msg, notify)
  if type(msg) ~= "string" then
    msg = handle_input(msg)
  end
  if notify then
    vim.notify(msg, vim.log.levels.WARN)
  end
  get_logger().warn(msg)
end

---Log and throw error.
--- WARNING: notifying causes issues when logging from async context.
---@param msg string|table
---@param notify boolean|nil Whether to also notify the user
function M.error(msg, notify)
  if type(msg) ~= "string" then
    msg = handle_input(msg)
  end
  if notify then
    vim.notify(msg, vim.log.levels.ERROR)
  end
  get_logger().error(msg)
  error(msg)
end

function M.get_level()
  return get_logger()._level
end

return M
