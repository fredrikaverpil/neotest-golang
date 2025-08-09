--- Unified error extraction and processing for neotest-golang.
---
--- This module consolidates all error processing logic used in both streaming
--- and non-streaming modes, providing consistent error extraction and formatting.
---
--- Key features:
--- - Supports multiple error patterns: Go compiler errors, test failures, testify assertions
--- - Handles both batch processing (full output) and streaming (line-by-line)
--- - Extracts line numbers and error messages from various Go test output formats
--- - Provides fallback error messages when specific patterns aren't found
--- - Consistent error format across streaming and non-streaming modes

local M = {}

--- Extract error information from test output
--- @param output string The test output to parse
--- @param test_filename string|nil Optional test filename for more specific error matching
--- @return neotest.Error[]
function M.extract_errors_from_output(output, test_filename)
  local errors = {}

  -- Look for failure messages and line numbers in output
  for line in output:gmatch("[^\n]+") do
    -- Skip the RUN and FAIL header lines
    if not line:match("^=== RUN") and not line:match("^--- FAIL") then
      -- Pattern 1: filename.go:line:column: message
      local file, line_num, message =
        line:match("([^:]+%.go):(%d+):%d*:?%s*(.+)")
      if file and line_num then
        table.insert(errors, {
          message = message or line,
          line = tonumber(line_num) - 1, -- Convert to 0-based
        })
      -- Pattern 2: filename_test.go:line: message (from t.Error/t.Fatal)
      elseif line:match("_test%.go:%d+:") then
        local test_file, test_line, test_msg =
          line:match("([^:]+):(%d+):%s*(.+)")
        if test_file and test_line then
          table.insert(errors, {
            message = test_msg or line,
            line = tonumber(test_line) - 1,
          })
        end
      -- Pattern 3: Specific test filename pattern (from process.lua)
      elseif test_filename then
        local matched_line_number =
          string.match(line, test_filename .. ":(%d+):")
        if matched_line_number ~= nil then
          local line_number = tonumber(matched_line_number)
          local message = string.match(line, test_filename .. ":%d+: (.*)")
          if line_number ~= nil and message ~= nil then
            table.insert(errors, {
              line = line_number - 1, -- neovim lines are 0-indexed
              message = message,
            })
          end
        end
      -- Pattern 4: Error Trace: ... (from testify)
      elseif line:match("Error Trace:") or line:match("Error:") then
        -- Extract the actual error message
        local error_msg = line:match("Error:%s*(.+)") or line
        table.insert(errors, {
          message = error_msg,
        })
      end
    end
  end

  -- If no specific errors found but test failed, extract the failure reason
  if #errors == 0 then
    -- Look for assertion failures or other error indicators
    for line in output:gmatch("[^\n]+") do
      if line:match("expected") or line:match("got") or line:match("want") then
        table.insert(errors, {
          message = vim.trim(line),
        })
        break
      end
    end

    -- Still no errors? Add generic message
    if #errors == 0 and output:match("FAIL") then
      table.insert(errors, {
        message = "Test failed - see output for details",
      })
    end
  end

  return errors
end

--- Extract errors from a single line of test output (for streaming)
--- @param line string The output line to process
--- @param test_filename string|nil Optional test filename for more specific error matching
--- @return neotest.Error|nil Single error if found
function M.extract_error_from_line(line, test_filename)
  -- Skip the RUN and FAIL header lines
  if line:match("^=== RUN") or line:match("^--- FAIL") then
    return nil
  end

  -- Pattern 1: filename.go:line:column: message
  local file, line_num, message = line:match("([^:]+%.go):(%d+):%d*:?%s*(.+)")
  if file and line_num then
    return {
      message = message or line,
      line = tonumber(line_num) - 1, -- Convert to 0-based
    }
  end

  -- Pattern 2: filename_test.go:line: message (from t.Error/t.Fatal)
  if line:match("_test%.go:%d+:") then
    local test_file, test_line, test_msg = line:match("([^:]+):(%d+):%s*(.+)")
    if test_file and test_line then
      return {
        message = test_msg or line,
        line = tonumber(test_line) - 1,
      }
    end
  end

  -- Pattern 3: Specific test filename pattern
  if test_filename then
    local matched_line_number = string.match(line, test_filename .. ":(%d+):")
    if matched_line_number ~= nil then
      local line_number = tonumber(matched_line_number)
      local message = string.match(line, test_filename .. ":%d+: (.*)")
      if line_number ~= nil and message ~= nil then
        return {
          line = line_number - 1, -- neovim lines are 0-indexed
          message = message,
        }
      end
    end
  end

  -- Pattern 4: Error Trace: ... (from testify)
  if line:match("Error Trace:") or line:match("Error:") then
    -- Extract the actual error message
    local error_msg = line:match("Error:%s*(.+)") or line
    return {
      message = error_msg,
    }
  end

  -- Pattern 5: Assertion failures
  if line:match("expected") or line:match("got") or line:match("want") then
    return {
      message = vim.trim(line),
    }
  end

  return nil
end

--- Process test output and extract errors for streaming mode
--- @param output_lines string[] Array of output lines
--- @param test_filename string|nil Optional test filename for more specific error matching
--- @return neotest.Error[]
function M.process_streaming_errors(output_lines, test_filename)
  local errors = {}

  for _, line in ipairs(output_lines) do
    local error = M.extract_error_from_line(line, test_filename)
    if error then
      table.insert(errors, error)
    end
  end

  -- If no specific errors found but output contains FAIL, add generic message
  if #errors == 0 then
    local output_text = table.concat(output_lines, "\n")
    if output_text:match("FAIL") then
      table.insert(errors, {
        message = "Test failed - see output for details",
      })
    end
  end

  return errors
end

return M

