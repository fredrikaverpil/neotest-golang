local M = {}

function M.sanitize_string(str)
  local sanitized_string = ""
  for i = 1, #str do
    local byte = string.byte(str, i)
    -- Preserve:
    -- - newlines (10)
    -- - tabs (9)
    -- - regular ASCII printable chars (32-127)
    -- This ensures we keep readable output while filtering binary noise
    if byte == 9 or byte == 10 or (byte >= 32 and byte <= 127) then
      sanitized_string = sanitized_string .. string.char(byte)
    else
      -- Optionally replace binary chars with a placeholder
      -- This helps identify where binary data was removed
      -- sanitized_string = sanitized_string .. "·"
    end
  end
  return sanitized_string
end

function M.sanitize_table(data)
  if type(data) == "table" then
    local new_table = {} -- Create a copy to avoid modifying the original table directly
    for k, v in pairs(data) do
      local sanitized_key = M.sanitize_string(tostring(k)) -- Sanitize keys (convert to string first)
      new_table[sanitized_key] = M.sanitize_table(v) -- Recursively sanitize values
    end
    return new_table
  elseif type(data) == "string" then
    return M.sanitize_string(data)
  elseif type(data) == "number" or type(data) == "boolean" or data == nil then
    return data -- numbers, booleans and nil are fine
  else
    return tostring(data) -- Convert other types to string and sanitize
  end
end

return M
