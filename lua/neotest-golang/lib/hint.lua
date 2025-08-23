local M = {}

--- Checks if the given line contains t.Log or t.Logf output (should be treated as hint)
---@param line string
---@return boolean
function M.is_test_log_hint(line)
  if not line then
    return false
  end

  -- Check if it matches test output format: "go:line: message"
  local pattern = "go:%d+: (.*)"
  local message = line:match(pattern)
  if not message then
    return false
  end

  -- Check if message contains typical error/failure indicators
  local error_indicators = {
    "panic:",
    "fatal error:",
    "expected.*but.*got",
    "expected.*but.*",
    "expected.*actual",
    "assertion failed",
    "test.*failed",
    "error:",
    "fail:",
    "FAIL:",
    "--- FAIL:",
    "runtime error:",
    "nil pointer dereference",
    "index out of range",
    "slice bounds out of range",
  }

  local lower_message = message:lower()
  for _, indicator in ipairs(error_indicators) do
    if lower_message:match(indicator:lower()) then
      return false
    end
  end

  return true
end

--- Extract hint diagnostics from test output lines
---@param lines table<string>
---@return table<{line: number, message: string, severity: number}>
function M.extract_hints_from_output(lines)
  local hints = {}

  for _, line in ipairs(lines) do
    if M.is_test_log_hint(line) then
      local pattern = "go:(%d+): (.*)"
      local line_number, message = line:match(pattern)

      if line_number and message then
        table.insert(hints, {
          line = tonumber(line_number) - 1, -- neovim lines are 0-indexed
          message = message,
          severity = vim.diagnostic.severity.HINT,
        })
      end
    end
  end

  return hints
end

return M
