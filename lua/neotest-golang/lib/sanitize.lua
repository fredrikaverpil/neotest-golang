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
  local sanitized_string = ""
  for i = 1, #str do
    local byte = string.byte(str, i)
    -- Preserve:
    -- - newlines (10)
    -- - tabs (9)
    -- - regular ASCII printable chars (32-127)
    -- This ensures we keep readable output while filtering binary noise
    if byte == 9 or byte == 10 or (byte >= 32 and byte <= 126) then
      sanitized_string = sanitized_string .. string.char(byte)
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
