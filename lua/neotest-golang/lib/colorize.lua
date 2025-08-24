local options = require("neotest-golang.options")

local M = {}

--- Colorize output parts (optimized version)
--- @param output_parts table[] Array of output strings
--- @return table[] Array of colorized lines ready for file output
function M.colorize_parts(output_parts)
  if not options.get().colorize_test_output == true or not output_parts then
    -- If colorization disabled, still need to split into lines for file output
    local lines = {}
    for _, part in ipairs(output_parts) do
      if part then
        local part_lines = vim.split(part, "\n", { trimempty = true })
        vim.list_extend(lines, part_lines)
      end
    end
    return lines
  end

  local colorized_lines = {}

  for _, part in ipairs(output_parts) do
    if part then
      -- Split part into lines if it contains newlines
      local lines = vim.split(part, "\n", { trimempty = true })
      for _, line in ipairs(lines) do
        -- Apply colorization logic (same as current function)
        local colorized_line = line
        local color_applied = false

        if string.find(line, "FAIL") then
          colorized_line = "\27[31m" .. line .. "\27[0m" -- red
          color_applied = true
        elseif string.find(line, "PASS") then
          colorized_line = "\27[32m" .. line .. "\27[0m" -- green
          color_applied = true
        elseif string.find(line, "WARN") then
          colorized_line = "\27[33m" .. line .. "\27[0m" -- yellow
          color_applied = true
        elseif string.find(line, "RUN") then
          colorized_line = "\27[34m" .. line .. "\27[0m" -- blue
          color_applied = true
        elseif string.find(line, "SKIP") then
          colorized_line = "\27[35m" .. line .. "\27[0m" -- purple
          color_applied = true
        end

        -- Only use colorized version if color was applied, otherwise use original line
        if color_applied then
          table.insert(colorized_lines, colorized_line)
        else
          table.insert(colorized_lines, line)
        end
      end
    end
  end

  return colorized_lines
end

return M
