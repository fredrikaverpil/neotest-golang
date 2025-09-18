local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")

local M = {}

---Convert to Neotest position id pattern.
---@param golist_data GoListItem[] Golist data containing package information
---@param package_name string The name of the package
---@return string|nil The pattern for matching against a test's position id in the neotest tree
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

--- Converts the test name into a regexp-friendly pattern, for usage in 'go test'.
---@param test_name string Test name to convert to regex pattern
---@return string Escaped regex pattern suitable for 'go test -run'
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

---Convert AST-detected Neotest position ID to `go test` test name format
---@param pos_id string Neotest position ID like /path/file.go::TestName::"SubTest"::"Nested"
---@return string|nil Go test name like "TestName/SubTest/Nested" or nil if invalid
-- TODO: this is part of streaming hot path. To be optimized.
function M.pos_id_to_go_test_name(pos_id)
  -- Validate input
  if type(pos_id) ~= "string" then
    return nil
  end

  -- Extract everything after the first ::
  local test_part = pos_id:match("::(.*)")
  if not test_part then
    return nil
  end

  local parts = vim.split(test_part, "::", { plain = true, trimempty = true })
  local go_test_parts = {}

  for idx, part in ipairs(parts) do
    -- Trim surrounding whitespace
    part = part:gsub("^%s*(.-)%s*$", "%1")
    if idx == 1 then
      -- Preserve main test name exactly as provided by Neotest AST-parsing
      table.insert(go_test_parts, part)
    else
      -- Sub-test name: strip surrounding quotes, unescape inner quotes, normalize whitespace to underscore
      local sub = part:gsub('^"(.*)"$', "%1")
      sub = sub:gsub('\\"', '"')
      sub = sub:gsub("%s+", "_")
      table.insert(go_test_parts, sub)
    end
  end

  return table.concat(go_test_parts, "/")
end

---Convert `go test` test name to Neotest position ID format
---@param go_test_name string Go test name like "TestName/SubTest/Nested"
---@return string Neotest format like TestName::"SubTest"::"Nested"
function M.go_test_name_to_pos_id(go_test_name)
  local parts = vim.split(go_test_name, "/", { plain = true, trimempty = true })
  local pos_parts = {}
  local idx = 0

  for _, part in ipairs(parts) do
    if part ~= "" then
      idx = idx + 1
      if idx == 1 then
        -- Main test name (no quotes)
        table.insert(pos_parts, part)
      else
        -- Sub-test: add quotes and convert underscores to spaces
        local subtest = '"' .. part:gsub("_", " ") .. '"'
        table.insert(pos_parts, subtest)
      end
    end
  end

  return table.concat(pos_parts, "::")
end

---Convert file path to Go import path using directory mapping
---@param file_path string Full path to test file
---@param import_to_dir table<string, string> Mapping of import paths to directories
---@return string|nil Import path or nil if not found
-- TODO: this is part of streaming hot path. To be optimized.
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

  if options.get().dev_notifications then
    logger.warn("No import path found for directory: " .. file_dir)
  else
    logger.debug("No import path found for directory: " .. file_dir)
  end
  return nil
end

---Convert Neotest position ID to Go test filename
---@param pos_id string Position ID like "/path/to/file_test.go::TestName" or synthetic ID like "github.com/pkg::TestName"
---@return string|nil Filename like "file_test.go" or nil if not a file path
function M.pos_id_to_filename(pos_id)
  if not pos_id then
    return nil
  end

  -- Check if it looks like a file path (contains "/" and ends with ".go")
  local file_path = pos_id:match("^([^:]+)")
  if file_path and file_path:match("%.go$") and file_path:match("/") then
    -- Extract just the filename from the full path
    return file_path:match("([^/]+)$")
  end

  return nil
end

return M
