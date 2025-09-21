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

  -- First pass: collect all test nodes with their resolved package + go test name
  ---@type { package_import: string, go_test_name: string, pos_id: string }[]
  local collected = {}

  -- Limit the number of nodes processed to prevent overwhelming large projects
  local max_nodes = 50000
  local processed_nodes = 0

  for _, node in tree:iter_nodes() do
    local pos = node:data()
    if pos.type == "test" then
      stats.processed = stats.processed + 1
      processed_nodes = processed_nodes + 1

      -- Stop processing if we've hit the limit
      if processed_nodes > max_nodes then
        logger.warn(
          "Reached maximum node processing limit ("
            .. max_nodes
            .. "), some tests may not be mapped"
        )
        break
      end

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

  -- Helper to add mapping without overwriting existing keys
  local function add_mapping(key, pos_id)
    if not lookup[key] then
      lookup[key] = pos_id
      stats.mapped = stats.mapped + 1
      logger.debug("Mapped: " .. key .. " -> " .. pos_id)
    end
  end

  -- Track exact keys to avoid creating phantom prefix mappings
  local exact_keys = {}

  -- Second pass: add exact mappings for all tests
  for _, item in ipairs(collected) do
    local key = item.package_import .. "::" .. item.go_test_name
    add_mapping(key, item.pos_id)
    exact_keys[key] = true
  end

  -- Third pass: only add prefix keys if that exact test node exists in the tree
  for _, item in ipairs(collected) do
    local segments =
      vim.split(item.go_test_name, "/", { plain = true, trimempty = true })
    if #segments > 1 then
      local prefix = nil
      for i, seg in ipairs(segments) do
        prefix = (i == 1) and seg or (prefix .. "/" .. seg)
        local key = item.package_import .. "::" .. prefix
        if exact_keys[key] then
          -- Do not overwrite existing exact mappings (e.g., top-level test nodes)
          add_mapping(key, item.pos_id)
        end
      end
    end
  end

  logger.debug("Position mapping stats:" .. vim.inspect(stats))
  return lookup
end

---Get position ID from go test event using lookup
---@param lookup table<string, string> The position lookup table
---@param package_import string Go package import path
---@param test_name string Go test name (may include slashes for subtests)
---@return string|nil Position ID or nil if not found
function M.get_pos_id(lookup, package_import, test_name)
  local internal_key = package_import .. "::" .. test_name
  local pos_id = lookup[internal_key]

  if not pos_id then
    -- TODO: save the entries and report later, in bulk, outside of async context.
    -- This also means we can enable notify.
    if options.get().dev_notifications then
      logger.warn("Test was executed but not detected: " .. internal_key, false)
    else
      logger.debug("Test was executed but not detected: " .. internal_key)
    end
  end

  return pos_id
end

return M
