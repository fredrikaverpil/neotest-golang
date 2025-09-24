--- This module handles duplicate subtest detection and warnings

local convert = require("neotest-golang.lib.convert")
local logger = require("neotest-golang.lib.logging")
local path = require("neotest-golang.lib.path")

local M = {}

--- Find duplicate subtests within the same parent test and file
--- @param tree neotest.Tree The neotest tree structure
function M.warn_duplicate_tests(tree)
  -- Build a map of (file_path, parent_test) -> list of subtest names
  local parent_to_subtests = {}

  -- First pass: collect all test positions and organize by parent and file
  for _, node in tree:iter_nodes() do
    local pos = node:data()
    if pos.type == "test" then
      -- Use existing convert function to get go test name
      local go_test_name = convert.pos_id_to_go_test_name(pos.id)
      if go_test_name then
        -- Split into parts using Go's "/" separator
        local parts =
          vim.split(go_test_name, "/", { plain = true, trimempty = true })

        if #parts > 1 then
          -- This is a subtest (has more than just the main test name)
          -- Build parent test name (all parts except the last)
          local parent_parts = {}
          for i = 1, #parts - 1 do
            table.insert(parent_parts, parts[i])
          end
          local parent_test_name = table.concat(parent_parts, "/")

          -- Get the subtest name (last part)
          local subtest_name = parts[#parts]

          -- Extract file path from position ID
          local file_path = path.extract_file_path_from_pos_id(pos.id)
          if file_path then
            -- Create composite key (file_path + parent_test) to ensure duplicates are only flagged within the same file
            local composite_key = file_path .. "::" .. parent_test_name

            -- Initialize parent entry if it doesn't exist
            if not parent_to_subtests[composite_key] then
              parent_to_subtests[composite_key] = {}
            end

            -- Track this subtest under its parent (within the same file)
            if not parent_to_subtests[composite_key][subtest_name] then
              parent_to_subtests[composite_key][subtest_name] = {}
            end
            table.insert(
              parent_to_subtests[composite_key][subtest_name],
              pos.id
            )
          end
        end
      end
    end
  end

  -- Second pass: find duplicates and build consolidated warning
  local duplicate_set = {}
  local found_duplicates = false

  for composite_key, subtests in pairs(parent_to_subtests) do
    -- Extract parent test name from composite key for display purposes
    local parent_test_name = composite_key:match("::(.+)$")
    for subtest_name, pos_ids in pairs(subtests) do
      if #pos_ids > 1 then
        found_duplicates = true
        -- Add unique duplicate entry to our set
        local duplicate_entry =
          string.format("%s::%s", parent_test_name, subtest_name)
        duplicate_set[duplicate_entry] = true
      end
    end
  end

  if found_duplicates then
    -- Build consolidated warning message with unique entries
    local warning_lines = { "Found duplicate subtest names:" }

    -- Convert set to sorted list for consistent output
    local duplicates_list = {}
    for duplicate_entry, _ in pairs(duplicate_set) do
      table.insert(duplicates_list, duplicate_entry)
    end
    table.sort(duplicates_list)

    for _, duplicate_entry in ipairs(duplicates_list) do
      table.insert(warning_lines, "  " .. duplicate_entry)
    end
    table.insert(warning_lines, "")
    table.insert(
      warning_lines,
      "Go will append suffixes like '#01' to distinguish them, but this may cause confusion."
    )
    table.insert(warning_lines, "Consider using unique subtest names.")
    table.insert(
      warning_lines,
      "You can suppress this warning by setting warn_test_name_dupes = false."
    )

    local warning = table.concat(warning_lines, "\n")
    logger.warn(warning, true)
  end
end

return M
