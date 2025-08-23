local patterns = require("neotest-golang.lib.patterns")

local M = {}

--- Checks if the given line contains t.Log or t.Logf output (should be treated as hint)
--- Now uses optimized pattern parsing
---@param line string
---@return boolean
function M.is_test_log_hint(line)
  local diagnostic = patterns.parse_diagnostic_line(line)
  if not diagnostic then
    return false
  end
  
  return diagnostic.severity == vim.diagnostic.severity.HINT
end

--- Extract hint diagnostics from test output lines
--- Now uses optimized single-pass pattern matching
---@param lines table<string>
---@return table<{line: number, message: string, severity: number}>
function M.extract_hints_from_output(lines)
  local hints = {}

  for _, line in ipairs(lines) do
    local diagnostic = patterns.parse_diagnostic_line(line)
    if diagnostic and diagnostic.severity == vim.diagnostic.severity.HINT then
      table.insert(hints, {
        line = diagnostic.line_number - 1, -- neovim lines are 0-indexed
        message = diagnostic.message,
        severity = diagnostic.severity,
      })
    end
  end

  return hints
end

return M
