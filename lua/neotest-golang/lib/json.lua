---JSON processing helpers.

local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")
local sanitize = require("neotest-golang.lib.sanitize")

local M = {}

---Decode JSON from a table of strings into a table of objects.
---@param lines string[] Array of strings, each string is a line
---@param construct_invalid boolean Whether to construct invalid lines into JSON objects
---@return table[] Array of decoded JSON objects
-- TODO: this is part of streaming hot path. To be optimized for performance.
function M.decode_from_table(lines, construct_invalid)
  local jsonlines = {}
  for _, line in ipairs(lines) do
    if string.match(line, "^%s*{") then -- must start with the `{` character
      local status, json_data = pcall(vim.json.decode, line)
      if status then
        if options.get().sanitize_output then
          json_data = sanitize.sanitize_table(json_data)
        end
        table.insert(jsonlines, json_data)
      else
        -- NOTE: this can be hit because of "Vim:E474: Unidentified byte: ..."
        logger.warn("Failed to decode JSON line: " .. line)
      end
    else
      logger.debug({ "Not valid JSON:", line })
      if construct_invalid then
        -- this is for example errors from stderr, when there is a compilation error
        if options.get().sanitize_output then
          line = sanitize.sanitize_string(line)
        end
        table.insert(jsonlines, { Action = "output", Output = line })
      end
    end
  end

  return jsonlines
end

---Decode JSON from a string into a table of objects.
---@param str string Multi-line JSON string with one JSON object per line
---@return table[] Array of decoded JSON objects
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
