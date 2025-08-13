local logger = require("neotest-golang.logging")

--- Converts one form of data to another.

local M = {}

--- Convert to Neotest position id pattern.
---@param golist_data table Golist data containing package information
---@param package_name string The name of the package
---@param test_name string The name of the test, which can include subtests separated by slashes
---@return string? The pattern for matching against a test's position id in the neotest tree
function M.to_test_position_id_pattern(golist_data, package_name, test_name)
  -- Example go list -json output:
  -- { {
  --     Dir = "/Users/fredrik/code/public/someproject/internal/foo/bar",
  --     ImportPath = "github.com/fredrikaverpil/someproject/internal/foo/bar",
  --     Module = {
  --       GoMod = "/Users/fredrik/code/public/someproject/go.mod"
  --     },
  --     Name = "bar",
  --     TestGoFiles = { "baz.go", "baz_test.go" },
  --     XTestGoFiles = {}
  --   } }
  --
  -- Example position id:
  -- '/Users/fredrik/code/public/someproject/internal/foo/bar/baz_test.go::TestName::"SubTestName"'

  for _, item in ipairs(golist_data) do
    if item.ImportPath == package_name then
      -- Found the package, construct the position id
      local dir = item.Dir

      -- Transform TestName/SubTest_Name into TestName::"SubTest Name"
      local test_parts = vim.split(test_name, "/", { trimempty = true })
      for i, part in ipairs(test_parts) do
        -- add quotes around subtests
        if i > 1 then
          -- TODO: underscore from `go test` could potentially be an actual underscore
          -- TODO: multiple subtests needs to be supported
          test_parts[i] = '"' .. part:gsub("_", " ") .. '"'
        end
      end
      local test_name_transformed = table.concat(test_parts, "::")

      local dir_escaped = M.to_lua_pattern(dir)
      local test_name_escaped = M.to_lua_pattern(test_name_transformed)
      local pattern = dir_escaped .. "/.*%.go::" .. test_name_escaped
      -- TODO: add ^ and $ to mark exact pattern ...?

      return pattern
    end
  end
end

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

--- Escape characters, for usage of string as pattern in Lua.
--- - `.` (matches any character)
--- - `%` (used to escape special characters)
--- - `+` (matches 1 or more of the previous character or class)
--- - `*` (matches 0 or more of the previous character or class)
--- - `-` (matches 0 or more of the previous character or class, in the shortest sequence)
--- - `?` (makes the previous character or class optional)
--- - `^` (at the start of a pattern, matches the start of the string; in a character class `[]`, negates the class)
--- - `$` (matches the end of the string)
--- - `[]` (defines a character class)
--- - `()` (defines a capture)
--- - `:` (used in certain pattern items like `%b()`)
--- - `=` (used in certain pattern items like `%b()`)
--- - `<` (used in certain pattern items like `%b<>`)
--- - `>` (used in certain pattern items like `%b<>`)
--- @param str string
function M.to_lua_pattern(str)
  local special_characters = {
    "%",
    ".",
    "+",
    "*",
    "-",
    "?",
    "^",
    "$",
    "[",
    "]",
    "(",
    ")",
    ":",
    "=",
    "<",
    ">",
    "\\",
  }
  for _, character in ipairs(special_characters) do
    str = str:gsub("%" .. character, "%%%" .. character)
  end
  return str
end

return M
