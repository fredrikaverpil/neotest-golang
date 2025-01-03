local M = {}

function M.sanitize_string(str)
  local sanitized_string = ""
  for i = 1, #str do
    local byte = string.byte(str, i)
    -- Check if byte is within the ANSI range
    local ansi_range = 127
    local ascii_range = 255
    if byte <= ansi_range then
      sanitized_string = sanitized_string .. string.char(byte)
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
