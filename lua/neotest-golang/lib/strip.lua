local M = {}

local convert = require("neotest-golang.lib.convert")

-- ANSI escape codes
M.ESCAPE = convert.to_lua_pattern(string.char(27))
M.CURSOR_HIDE = convert.to_lua_pattern(string.char(27) .. "[?25l")
M.CURSOR_SHOW = convert.to_lua_pattern(string.char(27) .. "[?25h")
M.CLEAR_SCREEN = convert.to_lua_pattern(string.char(27) .. "[2J")
M.RESET_ATTRIBUTES = convert.to_lua_pattern(string.char(27) .. "[m")
M.CURSOR_HOME = convert.to_lua_pattern(string.char(27) .. "[H")
M.BELL = convert.to_lua_pattern(string.char(7)) -- \a
M.SET_TITLE = convert.to_lua_pattern(string.char(27) .. "]0;")
  .. ".-"
  .. convert.to_lua_pattern(string.char(7))

-- Table of all codes to remove
M.CODES_TO_REMOVE = {
  M.ESCAPE .. "%[%d*[%.%d]*[%a%d]*", -- Catches most ANSI sequences
  M.CURSOR_HIDE,
  M.CURSOR_SHOW,
  M.CLEAR_SCREEN,
  M.RESET_ATTRIBUTES,
  M.CURSOR_HOME,
  M.BELL,
  M.SET_TITLE,
  convert.to_lua_pattern("[\0-\31\127]"), -- Control characters
}

-- Function to clean ANSI codes from a string
local function cleanString(str)
  if type(str) ~= "string" then
    return str
  end

  for _, code in ipairs(M.CODES_TO_REMOVE) do
    str = str:gsub(code, "")
  end
  return str:gsub("\n$", "") -- Remove trailing newline
end

-- Function to attempt JSON parsing with error recovery
local function safeJsonParse(str)
  -- First, try to parse the entire string
  local success, parsed = pcall(vim.json.decode, str)
  if success then
    return parsed
  end

  -- If that fails, try to find a valid JSON object within the string
  local jsonStart = str:find("{")
  local jsonEnd = str:reverse():find("}")
  if jsonStart and jsonEnd then
    local jsonStr = str:sub(jsonStart, -jsonEnd)
    success, parsed = pcall(vim.json.decode, jsonStr)
    if success then
      return parsed
    end
  end

  -- If all else fails, return the original string
  return str
end

-- Function to clean ANSI codes from a table
function M.cleanTable(tbl)
  if type(tbl) ~= "table" then
    return tbl
  end

  local cleanedTable = {}
  for i, item in ipairs(tbl) do
    local cleaned = cleanString(item)
    cleanedTable[i] = safeJsonParse(cleaned)
  end
  return cleanedTable
end

return M
