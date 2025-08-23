local M = {}

--- Pre-compiled patterns for Go test output parsing
--- Optimized to extract all needed information in single operations

--- Error indicators that classify a message as error vs hint
--- Using hash lookup for O(1) performance instead of iterative matching
M.error_indicators = {
  ["panic:"] = true,
  ["fatal error:"] = true,
  ["assertion failed"] = true,
  ["error:"] = true,
  ["fail:"] = true,
  ["runtime error:"] = true,
  ["nil pointer dereference"] = true,
  ["index out of range"] = true,
  ["slice bounds out of range"] = true,
}

--- Pattern for "expected...but...got" style assertions (case insensitive)
M.assertion_patterns = {
  "expected.*but.*got",
  "expected.*but.*",
  "expected.*actual",
  "test.*failed",
  "--- fail:",
}

--- Single comprehensive pattern to extract Go test output
--- Captures: filename_part, line_number, message
--- Supports both "go:123: message" and "filename.go:123: message" formats
M.go_output_pattern = "^%s*([%w_%-%.]*go):(%d+): (.*)"

--- Parse a single line of Go test output
--- @param line string The line to parse
--- @return table|nil Parsed data with {filename, line_number, message} or nil if no match
function M.parse_go_output_line(line)
  if not line then
    return nil
  end

  local filename, line_number_str, message = line:match(M.go_output_pattern)
  if not filename or not line_number_str or not message then
    return nil
  end

  local line_number = tonumber(line_number_str)
  if not line_number then
    return nil
  end

  return {
    filename = filename,
    line_number = line_number,
    message = message,
  }
end

--- Determine if a message should be classified as a hint vs error
--- @param message string The message content to classify
--- @return boolean True if message should be treated as hint, false for error
function M.is_hint_message(message)
  if not message then
    return false
  end

  local lower_message = message:lower()

  -- Check hash lookup for common error indicators (O(1))
  for indicator, _ in pairs(M.error_indicators) do
    if lower_message:find(indicator, 1, true) then -- plain text search
      return false
    end
  end

  -- Check assertion patterns that require regex matching
  for _, pattern in ipairs(M.assertion_patterns) do
    if lower_message:match(pattern:lower()) then
      return false
    end
  end

  return true
end

--- Parse Go test output line and classify as hint or error
--- @param line string The line to parse
--- @return table|nil Diagnostic data with {line_number, message, severity} or nil if no match
function M.parse_diagnostic_line(line)
  local parsed = M.parse_go_output_line(line)
  if not parsed then
    return nil
  end

  local is_hint = M.is_hint_message(parsed.message)
  local severity = is_hint and vim.diagnostic.severity.HINT or vim.diagnostic.severity.ERROR

  return {
    line_number = parsed.line_number,
    message = parsed.message,
    severity = severity,
  }
end

return M