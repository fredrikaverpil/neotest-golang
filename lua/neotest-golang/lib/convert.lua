local logger = require("neotest-golang.logging")

--- Converts one form of data to another.

local M = {}

-- REMOVED: to_test_position_id_pattern - replaced by mapping.lua O(1) lookup

--- Convert to Neotest position id pattern.
---@param golist_data table Golist data containing package information
---@param package_name string The name of the package
---@return string? The pattern for matching against a test's position id in the neotest tree
function M.to_dir_position_id(golist_data, package_name)
  for _, item in ipairs(golist_data) do
    if item.ImportPath == package_name then
      -- Found the package, construct the position id
      local pos_id = item.Dir
      return pos_id
    end
  end
  logger.error("Could not find position id for package: " .. package_name)
end

-- Converts the test name into a regexp-friendly pattern, for usage in
-- 'go test'.
---@param test_name string
---@return string
function M.to_gotest_regex_pattern(test_name)
  local special_characters = {
    "(",
    ")",
    "[",
    "]",
    "{",
    "}",
    "-",
    "|",
    "?",
    "+",
    "*",
    "^",
    "$",
  }
  for _, character in ipairs(special_characters) do
    test_name = test_name:gsub("%" .. character, "\\" .. character)
  end
  -- Each segment separated by '/' must be wrapped in an exact regex match.
  -- From Go docs:
  --    For tests, the regular expression is split by unbracketed
  --    slash (/) characters into a sequence of regular expressions, and each
  --    part of a test's identifier must match the corresponding element in
  --    the sequence, if any.
  local segments = {}
  for segment in string.gmatch(test_name, "[^/]+") do
    table.insert(segments, "^" .. segment .. "$")
  end

  return table.concat(segments, "/")
end

-- Converts the AST-detected Neotest node test name into the 'go test' command
-- test name format.
---@param pos_id string
---@return string
function M.to_gotest_test_name(pos_id)
  -- construct the test name
  local test_name = pos_id
  -- Remove the path before ::
  test_name = test_name:match("::(.*)$")
  -- Replace :: with /
  test_name = test_name:gsub("::", "/")
  -- Remove double quotes (single quotes are supported)
  test_name = test_name:gsub('"', "")
  -- Replace any spaces with _
  test_name = test_name:gsub(" ", "_")

  return test_name
end

-- REMOVED: to_lua_pattern - no longer needed with direct mapping approach

return M
