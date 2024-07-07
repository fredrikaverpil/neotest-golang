local M = {}

function M.deep(t, indent, done)
  done = done or {}
  indent = indent or ""
  local output = {}

  for k, v in pairs(t) do
    if type(v) == "table" and not done[v] then
      done[v] = true
      table.insert(
        output,
        indent .. tostring(k) .. ":\n" .. M.deep(v, indent .. "  ", done)
      )
    else
      table.insert(output, indent .. tostring(k) .. ": " .. tostring(v))
    end
  end

  return table.concat(output, "\n")
end

function M.dump(o)
  if type(o) == "table" then
    local s = "{ "
    for k, v in pairs(o) do
      if type(k) ~= "number" then
        k = '"' .. k .. '"'
      end
      s = s .. "[" .. k .. "] = " .. M.dump(v) .. ","
    end
    return s .. "} "
  else
    return tostring(o)
  end
end

return M
