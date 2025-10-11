local options = require("neotest-golang.options")

require("neotest-golang.lib.types")

local M = {}

---Captures testify assertion output format: "    Error Trace:	/path/to/file.go:123"
---Pattern breakdown: ^%s* (optional whitespace) Error Trace:%s+ (literal) (.+%.go) (path ending in .go) :(%d+) (number)
local testify_trace_pattern = "^%s*Error Trace:%s+(.+%.go):(%d+)"

---Captures testify error message: "    Error:          Should be false"
---Pattern breakdown: ^%s* (optional whitespace) Error:%s+ (literal) (.*) (error message)
local testify_error_pattern = "^%s*Error:%s+(.*)"

---Captures testify messages: "    Messages:       no shown"
---Pattern breakdown: ^%s* (optional whitespace) Messages:%s+ (literal) (.*) (message)
local testify_messages_pattern = "^%s*Messages:%s+(.*)"

---Captures testify test name: "    Test:           TestName"
---Pattern breakdown: ^%s* (optional whitespace) Test:%s+ (literal)
local testify_test_pattern = "^%s*Test:%s+"

---Parse a testify assertion output line for Error Trace
---@param line string The line to parse
---@return table|nil Parsed data with {filename, line_number, message} or nil if no match
local function parse_testify_trace_line(line)
  if not line then
    return nil
  end

  local filepath, line_number_str = line:match(testify_trace_pattern)
  if not filepath or not line_number_str then
    return nil
  end

  local line_number = tonumber(line_number_str)
  if not line_number then
    return nil
  end

  -- Extract just the filename from the full path
  local filename = filepath:match("([^/]+%.go)$") or filepath

  return {
    filename = filename,
    line_number = line_number,
    message = "assertion failed", -- Generic message, actual error comes from subsequent lines
  }
end

---Emit a diagnostic from pending state
---@param pending table Pending diagnostic state
---@return table Diagnostic data with {filename, line_number, message, severity}
local function emit_diagnostic(pending)
  return {
    filename = pending.filename,
    line_number = pending.line_number,
    message = pending.error_message,
    severity = vim.diagnostic.severity.ERROR,
  }
end

---Parse testify-specific diagnostic patterns
---
---Testify assertions produce multiline error output that must be parsed incrementally.
---This function implements a state machine to accumulate information across lines.
---
---Example testify error output:
---```
---    Error Trace:	/path/to/file.go:123
---    Error:      	Not equal:
---                	expected: 1
---                	actual  : 2
---    Test:       	TestExample
---    Messages:   	custom error message
---```
---
---The parser transitions through these states:
---  1. Wait for "Error Trace:" to capture file location
---  2. Wait for "Error:" to capture the assertion message (may span multiple lines)
---  3. Wait for "Test:" line (signals end of multiline error details)
---  4. Optionally capture "Messages:" line (custom user message appended to error)
---  5. Emit the complete diagnostic
---
---Multiple assertions can appear consecutively. When a new "Error Trace:" appears
---while processing an existing error, the pending diagnostic is flushed first.
---
---@param line string The line to parse
---@param context table Context to maintain state across multiple lines
---@return table|nil Diagnostic data with {filename, line_number, message, severity} or nil if no match
---@return table Updated context for multi-line parsing
function M.parse_testify_diagnostic(line, context)
  if not options.get().testify_enabled then
    return nil, context
  end

  local pending = context.testify_pending

  -- Start of new testify error: Error Trace line
  local testify_trace = parse_testify_trace_line(line)
  if testify_trace then
    -- Flush any pending diagnostic before starting a new one
    if pending and pending.error_message then
      local result = emit_diagnostic(pending)
      context.testify_pending = testify_trace
      return result, context
    end
    context.testify_pending = testify_trace
    return nil, context
  end

  -- No pending diagnostic, nothing to do
  if not pending then
    return nil, context
  end

  -- Waiting for Error message
  if not pending.error_message then
    local error_message = line:match(testify_error_pattern)
    if error_message then
      pending.error_message = error_message:gsub("^%s+", ""):gsub("%s+$", "")
    end
    return nil, context
  end

  -- Already have Error message, check for Messages line
  local messages = line:match(testify_messages_pattern)
  if messages then
    pending.error_message = pending.error_message
      .. ": "
      .. messages:gsub("^%s+", ""):gsub("%s+$", "")
    local result = emit_diagnostic(pending)
    context.testify_pending = nil
    return result, context
  end

  -- Check for Test line (signals end of error block)
  if line:match(testify_test_pattern) then
    pending.seen_test_line = true
    return nil, context
  end

  -- After Test line with no Messages means we're done
  if pending.seen_test_line then
    local result = emit_diagnostic(pending)
    context.testify_pending = nil
    return result, context
  end

  -- Still in multiline error details, keep accumulating
  return nil, context
end

return M
