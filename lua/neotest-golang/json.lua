local M = {}

--- Process JSON and return objects of interest.
--- @param raw_output table
--- @return table
function M.process_json(raw_output)
  local jsonlines = {}
  for _, line in ipairs(raw_output) do
    if string.match(line, "^%s*{") then -- must start with the `{` character
      local status, json_data = pcall(vim.fn.json_decode, line)
      if status then
        table.insert(jsonlines, json_data)
      else
        -- NOTE: this is often hit because of "Vim:E474: Unidentified byte: ..."
        vim.notify("Failed to decode JSON line: " .. line, vim.log.levels.WARN)
      end
    else
      -- vim.notify("Not valid JSON: " .. line, vim.log.levels.DEBUG)
    end
  end
  return jsonlines
end

return M
