local convert = require("neotest-golang.lib.convert")

require("neotest-golang.lib.types")

local M = {}

M.error_patterns = {
  "---fail:",
  "assertion failed",
  "error:",
  "expect.*actual",
  "expect.*but.*",
  "expect.*got",
  "fail:",
  "fatal error:",
  "index out of range",
  "nil pointer dereference",
  "panic:",
  "runtime error:",
  "slice bounds out of range",
  "test.*failed",
}

---Captures both "go:123: message" and "filename.go:123: message" formats
---Pattern breakdown: ^%s* (optional whitespace) (.*go) (any chars ending in go) :(%d+): (number) (.*) (message)
M.go_output_pattern = "^%s*(.*go):(%d+): (.*)"

---Parse Go test output line and classify as hint or error
---@param line string The line to parse
---@param context table|nil Optional context to maintain state across multiple lines for testify parsing
---@return table|nil Diagnostic data with {filename, line_number, message, severity} or nil if no match
---@return table|nil Updated context for multi-line parsing
function M.parse_diagnostic_line(line, context)
  context = context or {}

  -- Try standard Go output parsing first
  local parsed = M.parse_go_output_line(line)
  if parsed then
    local is_hint = M.is_hint_message(parsed.message)
    local severity = is_hint and vim.diagnostic.severity.HINT
      or vim.diagnostic.severity.ERROR

    return {
      filename = parsed.filename,
      line_number = parsed.line_number,
      message = parsed.message,
      severity = severity,
    },
      context
  end

  -- If standard parsing failed, try testify-specific patterns
  local testify_diagnostics =
    require("neotest-golang.features.testify.diagnostics")
  return testify_diagnostics.parse_testify_diagnostic(line, context)
end

---Parse a single line of Go test output
---@param line string The line to parse
---@return table|nil Parsed data with {filename, line_number, message} or nil if no match
function M.parse_go_output_line(line)
  if not line then
    return nil
  end

  local filename, line_number_str, message = line:match(M.go_output_pattern)
  if not filename or not line_number_str or not message then
    return nil
  end

  -- Skip lines with empty messages (e.g., "hints_test.go:14: ")
  -- These are typically followed by testify's multi-line assertion output
  if message:match("^%s*$") then
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

---Determine if a message should be classified as a hint vs error
---@param message string The message content to classify
---@return boolean True if message should be treated as hint, false for error
function M.is_hint_message(message)
  if not message then
    return false
  end

  local lower_message = message:lower()

  -- Check error patterns
  for _, pattern in ipairs(M.error_patterns) do
    if lower_message:match(pattern:lower()) then
      return false
    end
  end

  return true
end

---Process diagnostics.
---@param test_entry TestEntry Test entry with metadata containing output_parts
---@return neotest.Error[] Array of diagnostic errors
function M.process_diagnostics(test_entry)
  if
    not test_entry.metadata.output_parts
    or #test_entry.metadata.output_parts == 0
  then
    return {}
  end

  ---@type neotest.Error[]
  local errors = {}

  local test_filename =
    convert.pos_id_to_filename(test_entry.metadata.position_id)
  local error_set = {}
  local context = {} -- Context for multi-line parsing (e.g., testify assertions)

  -- Process each output part directly
  for _, part in ipairs(test_entry.metadata.output_parts) do
    if part then
      -- Handle multi-line parts by splitting if needed
      local lines = vim.split(part, "\n", { trimempty = true })
      for _, line in ipairs(lines) do
        -- Use context-aware parsing for multi-line patterns
        local diagnostic, updated_context =
          M.parse_diagnostic_line(line, context)
        context = updated_context or context

        if diagnostic then
          -- Filter diagnostics by filename if we have both filenames
          local should_include_diagnostic = true
          if test_filename and diagnostic.filename then
            -- Only include diagnostic if it belongs to the test file
            should_include_diagnostic = (diagnostic.filename == test_filename)
          end

          if should_include_diagnostic then
            -- Create a unique key for duplicate detection
            local error_key = (diagnostic.line_number - 1)
              .. ":"
              .. diagnostic.message

            if not error_set[error_key] then
              error_set[error_key] = true
              table.insert(errors, {
                line = diagnostic.line_number - 1,
                message = diagnostic.message,
                severity = diagnostic.severity,
              })
            end
          end
        end
      end
    end
  end

  -- Check for any pending testify diagnostics at the end
  local testify_diagnostics =
    require("neotest-golang.features.testify.diagnostics")
  local final_diagnostic =
    testify_diagnostics.finalize_testify_diagnostic(context)
  if final_diagnostic then
    local should_include_diagnostic = true
    if test_filename and final_diagnostic.filename then
      should_include_diagnostic = (final_diagnostic.filename == test_filename)
    end

    if should_include_diagnostic then
      local error_key = (final_diagnostic.line_number - 1)
        .. ":"
        .. final_diagnostic.message

      if not error_set[error_key] then
        error_set[error_key] = true
        table.insert(errors, {
          line = final_diagnostic.line_number - 1,
          message = final_diagnostic.message,
          severity = final_diagnostic.severity,
        })
      end
    end
  end

  return errors
end

return M
