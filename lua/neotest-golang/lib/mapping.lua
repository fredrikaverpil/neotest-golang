local convert = require("neotest-golang.lib.convert")
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
      local package_import =
        convert.file_path_to_import_path(pos.path, import_to_dir)

      -- Extract go test name from position ID
      local go_test_name = convert.pos_id_to_go_test_name(pos.id)

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

return M
