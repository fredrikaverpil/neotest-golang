--- Helper utilities for testing "nearest test" functionality
--- This module provides functions to test Neotest's nearest position algorithm

local M = {}

--- Get the nearest test position for a given file and line number
--- Uses Neotest's internal nearest algorithm from lib.positions.nearest
--- @param file_path string Absolute path to the test file
--- @param line_number number Zero-indexed line number (Neotest uses 0-indexed lines)
--- @return table|nil position_data The nearest position data, or nil if not found
function M.get_nearest_position(file_path, line_number)
  assert(file_path, "file_path is required")
  assert(line_number ~= nil, "line_number is required")
  assert(type(line_number) == "number", "line_number must be a number")

  -- Ensure file exists
  if vim.fn.filereadable(file_path) ~= 1 then
    error("File not readable: " .. file_path)
  end

  local nio = require("nio")
  local adapter = require("neotest-golang")

  -- Discover positions for the file
  local tree =
    nio.tests.with_async_context(adapter.discover_positions, file_path)
  if not tree then
    error("Failed to discover positions for: " .. file_path)
  end

  -- Load Neotest's positions library
  local neotest_positions = require("neotest.lib.positions")

  -- Call the nearest algorithm
  local nearest_node = neotest_positions.nearest(tree, line_number)

  if not nearest_node then
    return nil
  end

  -- Return the position data
  return nearest_node:data()
end

--- Assert that the nearest position at the given line matches the expected position ID
--- Useful for concise test assertions
--- @param file_path string Absolute path to the test file
--- @param line_number number Zero-indexed line number
--- @param expected_position_id string Expected position ID
--- @param message string|nil Optional custom error message
function M.assert_nearest(file_path, line_number, expected_position_id, message)
  local pos = M.get_nearest_position(file_path, line_number)

  if not pos then
    error(
      message
        or string.format(
          "No nearest position found at line %d in %s",
          line_number,
          file_path
        )
    )
  end

  if pos.id ~= expected_position_id then
    error(
      message
        or string.format(
          "Expected position ID '%s' at line %d, but got '%s'",
          expected_position_id,
          line_number,
          pos.id
        )
    )
  end
end

--- Get position ID for a test at the given line
--- Convenience function that returns just the ID
--- @param file_path string Absolute path to the test file
--- @param line_number number Zero-indexed line number
--- @return string|nil position_id The position ID, or nil if not found
function M.get_nearest_id(file_path, line_number)
  local pos = M.get_nearest_position(file_path, line_number)
  return pos and pos.id or nil
end

return M
