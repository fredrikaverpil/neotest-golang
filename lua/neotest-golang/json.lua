local M = {}

--- Process output from 'go test -json' and return an iterable table.
--- @param raw_output table
--- @return table
function M.process_gotest_output(raw_output)
  local jsonlines = {}
  for _, line in ipairs(raw_output) do
    if string.match(line, "^%s*{") then -- must start with the `{` character
      local status, json_data = pcall(vim.fn.json_decode, line)
      if status then
        table.insert(jsonlines, json_data)
      else
        -- NOTE: this can be hit because of "Vim:E474: Unidentified byte: ..."
        vim.notify("Failed to decode JSON line: " .. line, vim.log.levels.WARN)
      end
    else
      -- vim.notify("Not valid JSON: " .. line, vim.log.levels.DEBUG)
    end
  end
  return jsonlines
end

--- Process output from 'go list -json' an iterable lua table.
--- @param raw_output string
--- @return table
function M.process_golist_output(raw_output)
  -- Split the input into separate JSON objects
  local json_objects = {}
  local current_object = ""
  for line in raw_output:gmatch("[^\r\n]+") do
    if line:match("^%s*{") and current_object ~= "" then
      table.insert(json_objects, current_object)
      current_object = ""
    end
    current_object = current_object .. line
  end
  table.insert(json_objects, current_object)

  -- Parse each JSON object
  local objects = {}
  for _, json_object in ipairs(json_objects) do
    local obj = vim.fn.json_decode(json_object)
    table.insert(objects, obj)
  end

  -- Return the table of objects
  return objects
end

return M
