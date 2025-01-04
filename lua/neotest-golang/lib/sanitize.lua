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

--- Sanitize a string by removing non-printable characters.
--- - `utf8.codes()` iterates over complete UTF-8 characters,
---   regardless of how many bytes they use (1-4 bytes per character)
--- - `utf8.codepoint()` correctly extracts the Unicode code point
---   from a complete UTF-8 sequence
--- - `utf8.char()` properly converts a code point back into the
---   correct UTF-8 byte sequence
---
---   This leverages https://github.com/uga-rosa/utf8.nvim
---@param str string
---@return string
function M.sanitize_string(str)
  local utf8 = require("utf8")
  local sanitized_string = ""

  for pos, _ in utf8.codes(str) do
    local codepoint = utf8.codepoint(str, pos)
    -- Allow:
    -- - tab (9)
    -- - newline (10)
    -- - carriage return (13)
    -- - regular printable ASCII (32-126)
    if
      codepoint == 9
      or codepoint == 10
      or codepoint == 13
      or (codepoint >= 32 and codepoint <= 126)
    then
      sanitized_string = sanitized_string .. utf8.char(codepoint)
    else
      sanitized_string = sanitized_string .. "?"
    end
  end

  return sanitized_string
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
