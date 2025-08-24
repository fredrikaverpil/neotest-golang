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

--- Convert neotest position ID to go test name format
--- @param pos_id string Neotest position ID like "/path/file.go::TestName::"SubTest"::"Nested""
--- @return string|nil Go test name like "TestName/SubTest/Nested" or nil if invalid
function M.pos_id_to_go_test_name(pos_id)
  -- Extract everything after the first ::
  local test_part = pos_id:match("::(.*)")
  if not test_part then
    return nil
  end

  -- Split by :: to handle nested subtests
  local parts = vim.split(test_part, "::", { trimempty = true })
  local go_test_parts = {}

  for i, part in ipairs(parts) do
    if i == 1 then
      -- Main test name (no quotes)
      table.insert(go_test_parts, part)
    else
      -- Sub-test name: remove quotes and convert spaces to underscores
      local subtest = part:gsub('^"', ""):gsub('"$', ""):gsub(" ", "_")
      table.insert(go_test_parts, subtest)
    end
  end

  return table.concat(go_test_parts, "/")
end

--- Convert file path to Go import path using directory mapping
--- @param file_path string Full path to test file
--- @param import_to_dir table<string, string> Mapping of import paths to directories
--- @return string|nil Import path or nil if not found
function M.file_path_to_import_path(file_path, import_to_dir)
  -- Get the directory containing the file
  local file_dir = file_path:match("(.+)/[^/]+$")
  if not file_dir then
    return nil
  end

  -- Find matching import path
  for import_path, dir in pairs(import_to_dir) do
    if dir == file_dir then
      return import_path
    end
  end

  logger.debug("No import path found for directory: " .. file_dir)
  return nil
end

--- Get position ID from go test event using O(1) lookup
--- @param lookup table<string, string> The position lookup table
--- @param package_name string Go package import path
--- @param test_name string Go test name (may include slashes for subtests)
--- @return string|nil Position ID or nil if not found
function M.get_position_id(lookup, package_name, test_name)
  local internal_key = package_name .. "::" .. test_name
  local pos_id = lookup[internal_key]

  if not pos_id then
    logger.debug("No position found for: " .. internal_key)
  end

  return pos_id
end

--- Convert go test name to neotest position ID format (reverse of pos_id_to_go_test_name)
--- @param go_test_name string Go test name like "TestName/SubTest/Nested"
--- @return string Neotest format like "TestName::"SubTest"::"Nested""
function M.go_test_name_to_pos_format(go_test_name)
  local parts = vim.split(go_test_name, "/", { trimempty = true })
  local pos_parts = {}

  for i, part in ipairs(parts) do
    if i == 1 then
      -- Main test name (no quotes)
      table.insert(pos_parts, part)
    else
      -- Sub-test: add quotes and convert underscores to spaces
      local subtest = '"' .. part:gsub("_", " ") .. '"'
      table.insert(pos_parts, subtest)
    end
  end

  return table.concat(pos_parts, "::")
end

return M
