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
---@param go_test_name string
---@return string
function M.to_neotest_test_name_pattern(go_test_name)
  -- construct the test name
  local test_name = go_test_name
  -- Add :: before the test name
  test_name = "::" .. test_name
  -- Replace / with ::
  test_name = test_name:gsub("/", "::")

  -- NOTE: double quotes are removed from the string we match against.

  -- Replace _ with space
  test_name = test_name:gsub("_", " ")

  -- Mark the end of the test name pattern
  test_name = test_name .. "$"

  return test_name
end

return M
