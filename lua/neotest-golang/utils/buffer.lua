local lib = require("neotest-golang.lib")

local M = {}

function M.filter(word)
  -- Get the current buffer
  local bufnr = vim.api.nvim_get_current_buf()

  -- Get all lines in the buffer
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Create a new table to store lines containing the word
  local new_lines = {}

  -- Iterate through all lines
  for _, line in ipairs(lines) do
    -- If the line contains "neotest-golang", add it to new_lines
    if line:match(lib.convert.to_lua_pattern(word)) then
      table.insert(new_lines, line)
    end
  end

  -- Replace the buffer contents with the new lines
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)

  vim.notify("Removed lines not containing '" .. word .. "'")
end

return M
