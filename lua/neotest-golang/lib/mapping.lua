local logger = require("neotest-golang.logging")

--- Fast position mapping between go test output and neotest tree positions.
--- Eliminates regex pattern matching with O(1) lookups.

local M = {}

--- Build a bidirectional lookup table between go test keys and neotest position IDs
--- @param tree neotest.Tree The neotest tree structure
--- @param golist_data table The 'go list -json' output
--- @return table<string, string> Lookup table: go_test_key -> pos_id
function M.build_position_lookup(tree, golist_data)
  local lookup = {}
  local stats = { processed = 0, mapped = 0, failed = 0 }

  -- Build import_path -> directory mapping for fast package resolution
  local import_to_dir = {}
  for _, item in ipairs(golist_data) do
    if item.ImportPath and item.Dir then
      import_to_dir[item.ImportPath] = item.Dir
    end
  end

  for _, node in tree:iter_nodes() do
    local pos = node:data()
    if pos.type == "test" then
      stats.processed = stats.processed + 1

      -- Extract package import path from file path
      local package_import = M.file_path_to_import_path(pos.path, import_to_dir)

      -- Extract go test name from position ID
      local go_test_name = M.pos_id_to_go_test_name(pos.id)

      if package_import and go_test_name then
        local internal_key = package_import .. "::" .. go_test_name
        lookup[internal_key] = pos.id
        stats.mapped = stats.mapped + 1

        logger.trace("Mapped: " .. internal_key .. " -> " .. pos.id)
      else
        stats.failed = stats.failed + 1
        logger.debug("Failed to map position: " .. pos.id)
      end
    end
  end

  logger.debug("Position mapping stats:" .. vim.inspect(stats))
  return lookup
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
    vim.notify(vim.inspect("No pos found for: " .. internal_key))
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
