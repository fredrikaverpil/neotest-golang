local M = {}

-- Converts the AST-detected test name into the 'go test' command test name format.
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
  -- Replace any special characters with . so to avoid breaking regexp
  test_name = test_name:gsub("%[", ".")
  test_name = test_name:gsub("%]", ".")
  test_name = test_name:gsub("%(", ".")
  test_name = test_name:gsub("%)", ".")
  -- Replace any spaces with _
  test_name = test_name:gsub(" ", "_")

  return test_name
end

return M
