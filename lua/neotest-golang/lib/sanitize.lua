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

function M.sanitize_string(str)
  -- Convert to UTF-8 codepoints and back to handle the string properly
  local sanitized_string = ""
  local pos = 1
  while pos <= #str do
    local byte = string.byte(str, pos)
    local char_len = 1

    -- Detect UTF-8 sequence length
    if byte >= 240 then -- 4 bytes
      char_len = 4
    elseif byte >= 224 then -- 3 bytes
      char_len = 3
    elseif byte >= 192 then -- 2 bytes
      char_len = 2
    end

    local char = string.sub(str, pos, pos + char_len - 1)

    -- Check if it's a valid UTF-8 sequence or allowed ASCII
    if byte == 9 or byte == 10 or (byte >= 32 and byte <= 126) then
      sanitized_string = sanitized_string .. char
    else
      sanitized_string = sanitized_string .. "?" -- Using ASCII replacement
    end

    pos = pos + char_len
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
