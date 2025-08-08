--- JSON processing helpers.

local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")
local sanitize = require("neotest-golang.lib.sanitize")

local M = {}

--- Helper: Try to decode a line as JSON and add to results if successful
--- @param line string The line to decode
--- @param results table The results table to add to
--- @return boolean success Whether the line was successfully decoded
local function try_decode_complete_json(line, results)
  local status, json_data = pcall(vim.json.decode, line)
  if not status then
    return false
  end

  if options.get().sanitize_output then
    json_data = sanitize.sanitize_table(json_data)
  end
  table.insert(results, json_data)
  return true
end

--- Helper: Wrap a non-JSON line as an output object
--- @param line string The line to wrap
--- @param results table The results table to add to
local function wrap_as_output(line, results)
  logger.debug({ "Not valid JSON:", line })
  if options.get().sanitize_output then
    line = sanitize.sanitize_string(line)
  end
  table.insert(results, { Action = "output", Output = line })
end

--- Helper: Handle an incomplete JSON accumulator
--- @param accumulator string The incomplete JSON
--- @param wrap_non_json boolean Whether to wrap as output
--- @param results table The results table to add to
--- @param reason string Reason for the incomplete JSON
local function handle_incomplete_json(
  accumulator,
  wrap_non_json,
  results,
  reason
)
  logger.warn(reason .. ": " .. string.sub(accumulator, 1, 50) .. "...")
  if wrap_non_json then
    if options.get().sanitize_output then
      accumulator = sanitize.sanitize_string(accumulator)
    end
    table.insert(results, { Action = "output", Output = accumulator })
  end
end

--- Helper: Check if a line looks like it could be part of JSON
--- @param line string The line to check
--- @return boolean
local function looks_like_json_continuation(line)
  -- JSON continuations typically start with quotes, brackets, or are whitespace
  return line:match('^%s*[",%[%]{}]') or line:match("^%s*$")
end

--- Helper: Process a line when we're accumulating incomplete JSON
--- @param line string Current line
--- @param accumulator string Current accumulator
--- @param wrap_non_json boolean Whether to wrap non-JSON as output
--- @param results table Results table
--- @return string|nil New accumulator value (nil means accumulation stopped)
local function process_line_while_accumulating(
  line,
  accumulator,
  wrap_non_json,
  results
)
  -- Check if this line starts a new JSON object
  if line:match("^%s*{") then
    -- New JSON object started, handle the incomplete one
    handle_incomplete_json(
      accumulator,
      wrap_non_json,
      results,
      "Incomplete JSON, new object started"
    )

    -- Try to decode the new line
    if try_decode_complete_json(line, results) then
      return nil -- Accumulation stopped, JSON was complete
    else
      return line -- Start accumulating this new incomplete JSON
    end
  end

  -- Check if line looks like JSON continuation
  if not looks_like_json_continuation(line) then
    -- Doesn't look like JSON, handle incomplete and wrap non-JSON
    handle_incomplete_json(
      accumulator,
      wrap_non_json,
      results,
      "Incomplete JSON interrupted by non-JSON"
    )
    if wrap_non_json then
      wrap_as_output(line, results)
    end
    return nil -- Stop accumulating
  end

  -- Try adding line to accumulator
  local test_json = accumulator .. line
  if try_decode_complete_json(test_json, results) then
    return nil -- JSON completed, stop accumulating
  else
    return test_json -- Continue accumulating
  end
end

--- Decode JSON from a table of strings into a table of objects.
--- Handles cases where JSON objects may be split across multiple array elements.
--- @param tbl table Array of strings that may contain JSON or non-JSON lines
--- @param wrap_non_json boolean Whether to wrap non-JSON lines as output objects
--- @return table Array of decoded JSON objects (and optionally wrapped non-JSON)
function M.decode_from_table(tbl, wrap_non_json)
  local results = {}
  local accumulator = nil

  for _, line in ipairs(tbl) do
    if accumulator then
      -- Currently accumulating an incomplete JSON object
      accumulator = process_line_while_accumulating(
        line,
        accumulator,
        wrap_non_json,
        results
      )
    elseif line:match("^%s*{") then
      -- Line starts with {, try to decode it
      if not try_decode_complete_json(line, results) then
        -- Incomplete JSON, start accumulating
        accumulator = line
      end
    elseif wrap_non_json then
      -- Non-JSON line and we should wrap it
      wrap_as_output(line, results)
    else
      -- Non-JSON line and not wrapping, just log it
      logger.debug({ "Not valid JSON:", line })
    end
  end

  -- Handle any leftover accumulator
  if accumulator then
    handle_incomplete_json(
      accumulator,
      wrap_non_json,
      results,
      "Incomplete JSON at end of input"
    )
  end

  return results
end

--- Decode JSON from a string into a table of objects.
--- @param str string
--- @return table
function M.decode_from_string(str)
  -- Split the input string into lines
  local lines = {}
  for line in str:gmatch("[^\r\n]+") do
    table.insert(lines, line)
  end
  -- Use the same logic as decode_from_table
  return M.decode_from_table(lines, false)
end

return M
