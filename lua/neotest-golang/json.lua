local M = {}

--- Process JSON and return objects of interest.
---@param raw_output table
---@return table
function M.process_json(raw_output)
  ---@type table
  local jsonlines = {}

  for _, line in ipairs(raw_output) do
    if string.match(line, "^%s*{") then -- must start with the `{` character
      local json_data = vim.fn.json_decode(line)
      table.insert(jsonlines, json_data)
    else
      -- TODO: log these to file instead...
      -- vim.notify("Warning, not a json line: " .. line)
    end
  end
  return jsonlines
end

return M
