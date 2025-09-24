local find = require("neotest-golang.lib.find")
local logger = require("neotest-golang.lib.logging")
local options = require("neotest-golang.options")
require("neotest-golang.lib.types")

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
function M.file_path_to_import_path(file_path, import_to_dir)
  -- Get the directory containing the file using cross-platform path handling
  local file_dir = find.get_directory(file_path)
  if not file_dir or file_dir == "" then
    return nil
  end

  -- Find matching import path
  for import_path, dir in pairs(import_to_dir) do
    if vim.fs.normalize(dir) == vim.fs.normalize(file_dir) then
      return import_path
    end
  end

  if options.get().dev_notifications then
    logger.warn("No import path found for directory: " .. file_dir, true)
  else
    logger.debug("No import path found for directory: " .. file_dir)
  end
  return nil
end

---Extract file path from Neotest position ID (handles Windows drive letters correctly)
---@param pos_id string Position ID like "/path/to/file_test.go::TestName" or "D:\\path\\file_test.go::TestName"
---@return string|nil File path part before "::" or nil if not found
function M.extract_file_path_from_pos_id(pos_id)
  if not pos_id or type(pos_id) ~= "string" or pos_id == "" then
    return nil
  end

  -- Find the first occurrence of "::" (which separates file path from test path)
  local separator_pos = pos_id:find("::")
  if separator_pos then
    return pos_id:sub(1, separator_pos - 1)
  end

  -- If no "::" found, treat the entire string as the file path
  return pos_id
end

---Convert Neotest position ID to Go test filename
---@param pos_id string Position ID like "/path/to/file_test.go::TestName" or synthetic ID like "github.com/pkg::TestName"
---@return string|nil Filename like "file_test.go" or nil if not a file path
function M.pos_id_to_filename(pos_id)
  if not pos_id then
    return nil
  end

  -- Extract file path using Windows-safe method
  local file_path = M.extract_file_path_from_pos_id(pos_id)
  if
    file_path
    and file_path:match("%.go$")
    and (file_path:match("/") or file_path:match("\\"))
  then
    -- Extract just the filename from the full path using platform-conditional utility
    return M.get_filename_fast(file_path)
  end

  return nil
end

---Platform-conditional filename extraction for optimal performance
---Uses fast vim.fs.basename for POSIX-style paths, safe find.get_filename for Windows-style paths
---@param path string File path to extract filename from
---@return string|nil Filename or nil if path is invalid
function M.get_filename_fast(path)
  if not path or type(path) ~= "string" or path == "" then
    return nil
  end

  -- Detect Windows-style paths (drive letters, UNC paths, backslashes)
  local is_windows_path = path:match("^[A-Za-z]:") -- Drive letter
    or path:match("^\\\\") -- UNC path
    or path:match("\\") -- Contains backslashes

  if is_windows_path then
    -- Windows-style path: Use our Windows-safe implementation
    return find.get_filename(path)
  else
    -- POSIX-style path: Use fast built-in C function
    return vim.fs.basename(path)
  end
end

return M
