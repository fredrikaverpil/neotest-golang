--- Generic assertion utilities for neotest-golang tests
--- These functions provide enhanced table comparison with support for excluding specific fields

local M = {}

-- Generic table assertion with excluded fields (like Go's assert.DeepEquals but with exclusions)
-- Compares all fields except those explicitly excluded
-- Supports dot-notation for nested fields (e.g., "run_spec.context.golist_data")
---@param actual table
---@param expected table
---@param excluded_fields string[] Fields to exclude from comparison (supports dot-notation)
---@param context_name string?
function M.assert_table_excluding_fields(
  actual,
  expected,
  excluded_fields,
  context_name
)
  context_name = context_name or "Table"
  excluded_fields = excluded_fields or {}

  assert.is_truthy(actual, context_name .. " should exist")
  assert.are.equal("table", type(actual), context_name .. " should be table")

  -- Helper function to deep copy a table while excluding specified fields
  local function deep_copy_excluding(source, path_prefix)
    path_prefix = path_prefix or ""

    if type(source) ~= "table" then
      return source
    end

    local result = {}
    for key, value in pairs(source) do
      local current_path = path_prefix == "" and key
        or (path_prefix .. "." .. key)

      -- Check if this path should be excluded
      local should_exclude = false
      for _, excluded_field in ipairs(excluded_fields) do
        if current_path == excluded_field then
          should_exclude = true
          break
        end
      end

      if not should_exclude then
        if type(value) == "table" then
          result[key] = deep_copy_excluding(value, current_path)
        else
          result[key] = value
        end
      end
    end

    return result
  end

  -- Create filtered copies
  local expected_filtered = deep_copy_excluding(expected)
  local actual_filtered = deep_copy_excluding(actual)

  -- Deep comparison of non-excluded fields
  assert.are.same(
    expected_filtered,
    actual_filtered,
    context_name
      .. " should match exactly (excluding: "
      .. table.concat(excluded_fields, ", ")
      .. ")"
  )
end

-- Specialized validators for common field types that are often excluded

---@param actual table
---@param field_name string
---@param context_name string?
function M.validate_output_field(actual, field_name, context_name)
  context_name = context_name or "Table"
  local output = actual[field_name]
  if output then
    assert.are.equal(
      "string",
      type(output),
      context_name .. "." .. field_name .. " should be string"
    )
    assert.is_true(
      vim.fn.filereadable(output) == 1,
      context_name .. "." .. field_name .. " file should be readable"
    )
  end
end

---@param actual table
---@param field_name string
---@param context_name string?
function M.validate_golist_data_field(actual, field_name, context_name)
  context_name = context_name or "Table"
  local golist_data = actual[field_name]
  assert.are.equal(
    "table",
    type(golist_data),
    context_name .. "." .. field_name .. " should be table"
  )
  assert.is_true(
    #golist_data > 0,
    context_name .. "." .. field_name .. " should not be empty"
  )
end

---@param actual table
---@param field_name string
---@param context_name string?
function M.validate_function_field(actual, field_name, context_name)
  context_name = context_name or "Table"
  local func = actual[field_name]
  assert.are.equal(
    "function",
    type(func),
    context_name .. "." .. field_name .. " should be function"
  )
end

-- Convenience functions for common neotest-golang types

-- Assert neotest.Result with explicit excluded fields
---@param actual_result neotest.Result
---@param expected_result neotest.Result
---@param excluded_fields string[]? Fields to exclude (defaults to {"output"})
---@param context_name string?
function M.assert_neotest_result(
  actual_result,
  expected_result,
  excluded_fields,
  context_name
)
  excluded_fields = excluded_fields or { "output" }
  context_name = context_name or "Result"

  M.assert_table_excluding_fields(
    actual_result,
    expected_result,
    excluded_fields,
    context_name
  )

  -- Validate commonly excluded fields if they were excluded
  for _, field in ipairs(excluded_fields) do
    if field == "output" then
      M.validate_output_field(actual_result, "output", context_name)
    end
  end
end

-- Assert RunspecContext with explicit excluded fields
---@param actual_context RunspecContext
---@param expected_context RunspecContext
---@param excluded_fields string[]? Fields to exclude (defaults to {"golist_data", "stop_stream"})
---@param context_name string?
function M.assert_runspec_context(
  actual_context,
  expected_context,
  excluded_fields,
  context_name
)
  excluded_fields = excluded_fields or { "golist_data", "stop_stream" }
  context_name = context_name or "Context"

  M.assert_table_excluding_fields(
    actual_context,
    expected_context,
    excluded_fields,
    context_name
  )

  -- Validate commonly excluded fields if they were excluded
  for _, field in ipairs(excluded_fields) do
    if field == "golist_data" then
      M.validate_golist_data_field(actual_context, "golist_data", context_name)
    elseif field == "stop_stream" then
      M.validate_function_field(actual_context, "stop_stream", context_name)
    end
  end
end

return M
