local M = {}

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

-- Converts the `go test` command test name into Neotest node test name format.
-- Note that a pattern can returned, not the exact test name, so to support
-- escaped quotes etc.
-- NOTE: double quotes must be removed from the string matching against.

---@param go_test_name string
---@return string
function M.to_neotest_test_name_pattern(go_test_name)
  -- construct the test name
  local test_name = go_test_name
  -- Add :: before the test name
  test_name = "::" .. test_name
  -- Replace / with ::
  test_name = test_name:gsub("/", "::")

  -- Replace _ with space
  test_name = test_name:gsub("_", " ")

  -- Mark the end of the test name pattern
  test_name = test_name .. "$"

  -- Percentage sign must be escaped
  test_name = test_name:gsub("%%", "%%%%")

  -- Literal brackets and parantheses must be escaped
  test_name = test_name:gsub("%[", "%%[")
  test_name = test_name:gsub("%]", "%%]")
  test_name = test_name:gsub("%(", "%%(")
  test_name = test_name:gsub("%)", "%%)")

  return test_name
end

function M.to_lua_pattern(str)
  -- Escape characters, for usage of string as pattern.
  -- - `.` (matches any character)
  -- - `%` (used to escape special characters)
  -- - `+` (matches 1 or more of the previous character or class)
  -- - `*` (matches 0 or more of the previous character or class)
  -- - `-` (matches 0 or more of the previous character or class, in the shortest sequence)
  -- - `?` (makes the previous character or class optional)
  -- - `^` (at the start of a pattern, matches the start of the string; in a character class `[]`, negates the class)
  -- - `$` (matches the end of the string)
  -- - `[]` (defines a character class)
  -- - `()` (defines a capture)
  -- - `:` (used in certain pattern items like `%b()`)
  -- - `=` (used in certain pattern items like `%b()`)
  -- - `<` (used in certain pattern items like `%b<>`)
  -- - `>` (used in certain pattern items like `%b<>`)

  local special_characters = {
    ".",
    "%",
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
  }
  for _, character in ipairs(special_characters) do
    str = str:gsub("%" .. character, "%%%" .. character)
  end
  return str
end

return M
