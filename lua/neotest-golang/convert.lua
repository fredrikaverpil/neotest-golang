local M = {}

-- Converts the test name into a regexp-friendly pattern, for usage in
-- 'go test'.
---@param test_name string
---@return string
function M.to_gotest_regex_pattern(test_name)
  local special_characters = {
    "(",
    ")",
  }
  for _, character in ipairs(special_characters) do
    test_name = test_name:gsub("%" .. character, "\\" .. character)
  end
  return "^" .. test_name .. "$"
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

--- Escape characters, for usage of string as pattern in Lua..
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
  }
  for _, character in ipairs(special_characters) do
    str = str:gsub("%" .. character, "%%%" .. character)
  end
  return str
end

return M
