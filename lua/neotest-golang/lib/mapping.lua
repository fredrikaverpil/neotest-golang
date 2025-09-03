local convert = require("neotest-golang.lib.convert")
local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")

local M = {}

---Build a bidirectional lookup table between internal `go test` keys its corresponding neotest position IDs.
---@param tree neotest.Tree The neotest tree structure
---@param golist_data table The 'go list -json' output
---@return table<string, string> Lookup table: go_test_key -> pos_id
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
      local package_import =
        convert.file_path_to_import_path(pos.path, import_to_dir)

      -- Extract go test name from position ID
      local go_test_name = convert.pos_id_to_go_test_name2(pos.id)

      if package_import and go_test_name then
        local internal_key = package_import .. "::" .. go_test_name
        lookup[internal_key] = pos.id
        stats.mapped = stats.mapped + 1
        logger.debug("Mapped: " .. internal_key .. " -> " .. pos.id)
      else
        stats.failed = stats.failed + 1
        if options.get().dev_notifications then
          logger.warn("Failed to map position: " .. pos.id)
        else
          logger.debug("Failed to map position: " .. pos.id)
        end
      end
    end
  end

  logger.debug("Position mapping stats:" .. vim.inspect(stats))
  return lookup
end

---Convert from test event Get position ID from go test event using lookup
---@param lookup table<string, string> The position lookup table
---@param package_import string Go package import path
---@param test_name string Go test name (may include slashes for subtests)
---@return string|nil Position ID or nil if not found
function M.get_pos_id(lookup, package_import, test_name)
  local internal_key = package_import .. "::" .. test_name
  local pos_id = lookup[internal_key]

  if not pos_id then
    if options.get().dev_notifications then
      logger.warn("No position found for: " .. internal_key)
    else
      logger.debug("No position found for: " .. internal_key)
    end
  end

  return pos_id
end

return M
