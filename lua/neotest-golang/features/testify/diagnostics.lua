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
---Pattern breakdown: ^%s* (optional whitespace) Messages:%s+ (literal) (.*) (messages)
local testify_messages_pattern = "^%s*Messages:%s+(.*)"

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

---Parse testify-specific diagnostic patterns
---@param line string The line to parse
---@param context table Context to maintain state across multiple lines
---@return table|nil Diagnostic data with {filename, line_number, message, severity} or nil if no match
---@return table Updated context for multi-line parsing
function M.parse_testify_diagnostic(line, context)
  if not options.get().testify_enabled then
    return nil, context
  end

  -- If we have a pending testify context and encounter a new Error Trace,
  -- flush the previous one first
  if context.testify_pending and context.testify_pending.error_message then
    local testify_trace = parse_testify_trace_line(line)
    if testify_trace then
      -- Return the previous pending diagnostic
      local result = {
        filename = context.testify_pending.filename,
        line_number = context.testify_pending.line_number,
        message = context.testify_pending.error_message,
        severity = vim.diagnostic.severity.ERROR,
      }
      -- Store the new trace info
      context.testify_pending = testify_trace
      return result, context
    end
  end

  -- Check if this is a testify Error Trace line
  local testify_trace = parse_testify_trace_line(line)
  if testify_trace then
    -- Store the trace info for potential error message on next lines
    context.testify_pending = testify_trace
    return nil, context
  end

  -- Check if this is a testify Error message line and we have pending trace
  if context.testify_pending then
    local error_message = line:match(testify_error_pattern)
    if error_message then
      -- Store the error message and continue looking for Messages line
      context.testify_pending.error_message =
        error_message:gsub("^%s+", ""):gsub("%s+$", "")
      return nil, context
    end

    -- Check if this is a testify Messages line and we have error message
    if context.testify_pending.error_message then
      local messages_content = line:match(testify_messages_pattern)
      if messages_content then
        -- Combine error message with messages
        local combined_message = context.testify_pending.error_message
          .. ": "
          .. messages_content:gsub("^%s+", ""):gsub("%s+$", "")
        local result = {
          filename = context.testify_pending.filename,
          line_number = context.testify_pending.line_number,
          message = combined_message,
          severity = vim.diagnostic.severity.ERROR,
        }
        context.testify_pending = nil -- Clear pending state
        return result, context
      end

      -- If this is a Test: line, just ignore it and continue looking for Messages
      if line:match("^%s*Test:%s+") then
        return nil, context
      end
    end
  end

  return nil, context
end

---Finalize any pending testify diagnostics
---@param context table Context that may contain pending testify data
---@return table|nil Diagnostic data if there was pending testify data
function M.finalize_testify_diagnostic(context)
  if context.testify_pending and context.testify_pending.error_message then
    local result = {
      filename = context.testify_pending.filename,
      line_number = context.testify_pending.line_number,
      message = context.testify_pending.error_message,
      severity = vim.diagnostic.severity.ERROR,
    }
    context.testify_pending = nil
    return result
  end
  return nil
end

return M
