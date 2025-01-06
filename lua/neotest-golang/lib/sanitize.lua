local logger = require("neotest-golang.logging")

local M = {}

local function isSequentialList(t)
  if type(t) ~= "table" then
    return false
  end

  local count = 0
  for _ in pairs(t) do
    count = count + 1
  end

  -- Check if all indices from 1 to count exist
  for i = 1, count do
    if t[i] == nil then
      return false
    end
  end

  return true
end

--- Sanitize a string by replacing control characters while preserving UTF-8.
--- Allows:
--- - Tab (U+0009)
--- - Line Feed/Newline (U+000A)
--- - Carriage Return (U+000D)
--- - All printable characters (U+0020 and above, except DEL U+007F)
---
--- Replaces:
--- - Control characters (U+0000-U+0008, U+000B-U+000C, U+000E-U+001F)
--- - Delete character (U+007F)
---
--- Uses the utf8.nvim library (https://github.com/uga-rosa/utf8.nvim) for proper UTF-8 handling.
---
---@param str string The input string to sanitize
---@param replacement string? Optional replacement character (defaults to U+FFFD REPLACEMENT CHARACTER)
---@return string The sanitized string
function M.sanitize_string(str, replacement)
  local success, utf8 = pcall(require, "utf8")
  if not success then
    logger.error("Failed to load uga-rosa/utf8.nvim")
  end

  replacement = replacement or utf8.char(0xFFFD) -- Unicode replacement character
  local sanitized_chars = {}

  for pos, _ in utf8.codes(str) do
    local codepoint = utf8.codepoint(str, pos)
    -- Allow:
    -- - tab (9)
    -- - newline (10)
    -- - carriage return (13)
    -- - all printable characters (>= 32)
    -- Filter out:
    -- - control characters (0-8, 11-12, 14-31)
    -- - delete character (127)
    if
      codepoint == 9
      or codepoint == 10
      or codepoint == 13
      or codepoint >= 32 and codepoint ~= 127
    then
      table.insert(sanitized_chars, utf8.char(codepoint))
    else
      table.insert(sanitized_chars, replacement)
    end
  end

  return table.concat(sanitized_chars)
end

function M.sanitize_table(data)
  if type(data) == "table" then
    local new_table = {} -- Create a copy to avoid modifying the original table directly

    if isSequentialList(data) then
      for i, v in ipairs(data) do
        new_table[i] = M.sanitize_table(v)
      end
    else
      for k, v in pairs(data) do
        local sanitized_key = M.sanitize_string(tostring(k))
        new_table[sanitized_key] = M.sanitize_table(v)
      end
    end

    return new_table
  elseif type(data) == "string" then
    return M.sanitize_string(data)
  elseif type(data) == "number" or type(data) == "boolean" or data == nil then
    return data
  else
    return tostring(data)
  end
end

return M
