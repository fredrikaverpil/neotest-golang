--- Functions for detecting and handling t.Log messages as hints rather than errors.

local M = {}

--- Checks if the given line contains t.Log or t.Logf output (should be treated as hint)
---@param line string
---@param test_filename string
---@return boolean
function M.is_test_log_hint(line, test_filename)
  if not line or not test_filename then
    return false
  end

  -- Check if it matches test output format: "    filename:line: message"
  local pattern = "%s%s%s%s" .. test_filename .. ":%d+: (.*)"
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
---@param test_filename string
---@return table<{line: number, message: string, severity: number}>
function M.extract_hints_from_output(lines, test_filename)
  local hints = {}

  for _, line in ipairs(lines) do
    if M.is_test_log_hint(line, test_filename) then
      local pattern = "%s%s%s%s" .. test_filename .. ":(%d+): (.*)"
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
