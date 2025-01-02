--- JSON processing helpers.

local logger = require("neotest-golang.logging")

local M = {}

--- Decode JSON from a table of strings into a table of objects.
--- @param tbl table
--- @param construct_invalid boolean
--- @return table
function M.decode_from_table(tbl, construct_invalid)
  local jsonlines = {}
  for _, line in ipairs(tbl) do
    if string.match(line, "^%s*{") then -- must start with the `{` character
      local status, json_data = pcall(vim.json.decode, line)
      if status then
        table.insert(jsonlines, json_data)
      else
        -- NOTE: this can be hit because of "Vim:E474: Unidentified byte: ..."
        logger.warn("Failed to decode JSON line: " .. line)
      end
    else
      logger.debug({ "Not valid JSON:", line })
      if construct_invalid then
        -- this is for example errors from stderr, when there is a compilation error
        table.insert(jsonlines, { Action = "output", Output = line })
      end
    end
  end
  return jsonlines
end

--- Decode JSON from a string into a table of objects.
--- @param str string
--- @return table
function M.decode_from_string(str)
  -- Split the input into separate JSON objects
  local tbl = {}
  local current_object = ""
  for line in str:gmatch("[^\r\n]+") do
    if line:match("^%s*{") and current_object ~= "" then
      table.insert(tbl, current_object)
      current_object = ""
    end
    current_object = current_object .. line
  end
  table.insert(tbl, current_object)
  return M.decode_from_table(tbl, false)
end

return M
