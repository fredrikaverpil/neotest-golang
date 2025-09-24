local convert = require("neotest-golang.lib.convert")
local logger = require("neotest-golang.lib.logging")
local metrics = require("neotest-golang.lib.metrics")
local options = require("neotest-golang.options")

local M = {}

---Build a bidirectional lookup table between internal `go test` keys its corresponding neotest position IDs.
---@param tree neotest.Tree The neotest tree structure
---@param golist_data table The 'go list -json' output
---@return table<string, string> Lookup table: go_test_key -> pos_id
function M.build_position_lookup(tree, golist_data)
  local stats = { processed = 0, mapped = 0, failed = 0 }

  -- Build import_path -> directory mapping for fast package resolution
  local import_to_dir = {}
  for _, item in ipairs(golist_data) do
    if item.ImportPath and item.Dir then
      import_to_dir[item.ImportPath] = item.Dir
    end
  end

  logger.debug("Import to directory mapping: " .. vim.inspect(import_to_dir))

  -- First pass: collect all test nodes with their resolved package + go test name
  ---@type { package_import: string, go_test_name: string, pos_id: string }[]
  local collected = {}
  for _, node in tree:iter_nodes() do
    local pos = node:data()
    if pos.type == "test" then
      stats.processed = stats.processed + 1

      local package_import =
        convert.file_path_to_import_path(pos.path, import_to_dir)
      local go_test_name = convert.pos_id_to_go_test_name(pos.id)

      if package_import and go_test_name then
        table.insert(collected, {
          package_import = package_import,
          go_test_name = go_test_name,
          pos_id = pos.id,
        })
      else
        stats.failed = stats.failed + 1
        if options.get().dev_notifications then
          logger.warn("Failed to map position: " .. pos.id, true)
        else
          logger.debug("Failed to map position: " .. pos.id)
        end
      end
    end
  end

  logger.debug("Collected test nodes: " .. vim.inspect(collected))

  -- Example of position id:
  -- /Users/fredrik/code/public/neotest-golang/tests/go/internal/specialchars/special_characters_test.go::TestNames::"Mixed case with space"
  --
  -- Example of collected item:
  -- {
  --   go_test_name = "TestNames/Mixed_case_with_space",
  --   package_import = "github.com/fredrikaverpil/neotest-golang/internal/specialchars",
  --   pos_id = '/Users/fredrik/code/public/neotest-golang/tests/go/internal/specialchars/special_characters_test.go::TestNames::"Mixed case with space"'
  -- }
  --
  -- Example of lookup entry [internal_id] = pos.id:
  -- ["github.com/fredrikaverpil/neotest-golang/internal/specialchars::TestNames/Mixed_case_with_space"] = '/Users/fredrik/code/public/neotest-golang/tests/go/internal/specialchars/special_characters_test.go::TestNames::"Mixed case with space"',

  local lookup = {}
  for _, item in ipairs(collected) do
    local internal_key = item.package_import .. "::" .. item.go_test_name
    lookup[internal_key] = item.pos_id
    stats.mapped = stats.mapped + 1
  end
  logger.debug("Lookup table: " .. vim.inspect(lookup))

  logger.debug("Position mapping stats:" .. vim.inspect(stats))
  return lookup
end

---Collection of failed position mappings for bulk reporting
---@type table<string, boolean>
M._failed_mappings = {}

---Get position ID from go test event using lookup
---@param lookup table<string, string> The position lookup table
---@param package_import string Go package import path
---@param test_name string Go test name (may include slashes for subtests)
---@return string|nil Position ID or nil if not found
function M.get_pos_id(lookup, package_import, test_name)
  local internal_key = package_import .. "::" .. test_name
  local pos_id = lookup[internal_key]

  -- Record position lookup for metrics
  local success = pos_id ~= nil
  metrics.record_position_lookup(success)

  if not success then
    -- Collect failed mappings for bulk reporting to avoid spam during streaming
    M._failed_mappings[internal_key] = true
  end

  return pos_id
end

---Report all collected failed position mappings and clear the collection
function M.report_failed_mappings()
  if vim.tbl_count(M._failed_mappings) > 0 then
    local failed_list = vim.tbl_keys(M._failed_mappings)
    table.sort(failed_list)

    local message = "Tests executed but not detected by tree-sitter query ("
      .. #failed_list
      .. " tests):\n"
      .. table.concat(failed_list, "\n")

    if options.get().dev_notifications then
      logger.warn(message, true)
    else
      logger.info(message)
    end

    -- Clear the collection after reporting
    M._failed_mappings = {}
  end
end

return M
