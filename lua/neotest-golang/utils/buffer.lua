local lib = require("neotest-golang.lib")

local M = {}

function M.filter(word)
  -- Get the current buffer
  local bufnr = vim.api.nvim_get_current_buf()

  -- Get all lines in the buffer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Create a new table to store filtered lines
  local new_lines = {}

  -- Flag to track if we're currently in a matching block
  local in_matching_block = false

  -- Iterate through all lines
  for _, line in ipairs(lines) do
    -- Check if the line starts with a log level
    local is_log_start = line:match("^%u+%s+|")

    if is_log_start then
      -- If it's a new log entry, reset the flag
      in_matching_block = false
    end

    -- If the line contains the word or we're in a matching block, add it
    if line:match(lib.convert.to_lua_pattern(word)) or in_matching_block then
      table.insert(new_lines, line)
      in_matching_block = true
    end
  end

  -- Replace the buffer contents with the new lines
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
end

return M
