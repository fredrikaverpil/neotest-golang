--- Unified position and test name resolution for neotest-golang.
--- Consolidates logic for converting neotest positions to Go test names and packages.

local logger = require("neotest-golang.logging")
local lib = require("neotest-golang.lib")

local M = {}

--- Extract test name from a neotest position
--- @param pos neotest.Position
--- @return string|nil
function M.extract_test_name_from_position(pos)
  -- The position ID typically has format: path::TestName
  -- or for subtests: path::TestName::SubTest or path::TestName::"SubTest"
  if not pos.id then
    return nil
  end
  
  local parts = vim.split(pos.id, "::")
  if #parts >= 2 then
    -- Remove the file path, keep test names
    table.remove(parts, 1)
    
    -- Reconstruct the test name
    local test_name = table.concat(parts, "::")
    
    -- Handle quoted subtest names (remove quotes and convert to Go format)
    -- Example: TestName::"SubTest" -> TestName/SubTest
    test_name = test_name:gsub('::?"([^"]+)"', '/%1')
    test_name = test_name:gsub('::"([^"]+)"', '/%1')
    
    -- Handle unquoted subtests
    -- Example: TestName::SubTest -> TestName/SubTest  
    test_name = test_name:gsub("::", "/")
    
    return test_name
  end
  
  return pos.name
end

--- Get the Go package for a position
--- @param pos neotest.Position
--- @param golist_data table
--- @return string|nil
function M.get_package_for_position(pos, golist_data)
  local file_path = pos.path
  if not file_path then
    return nil
  end
  
  local dir = vim.fn.fnamemodify(file_path, ":h")
  
  for _, item in ipairs(golist_data or {}) do
    if item.Dir == dir then
      return item.ImportPath
    end
  end
  
  return nil
end

--- Build a test identifier from package and test name
--- @param package string|nil
--- @param test_name string|nil
--- @return string|nil
function M.build_test_identifier(package, test_name)
  if not test_name then
    return nil
  end
  if package then
    return package .. "::" .. test_name
  end
  return test_name
end

--- Build a lookup table from go test names to neotest position IDs
--- @param tree neotest.Tree
--- @param golist_data table
--- @return table<string, string>
function M.build_position_lookup(tree, golist_data)
  local lookup = {}
  
  logger.debug("Building position lookup for tree")
  
  -- Handle single test node (when running a single test)
  if tree and tree.data then
    local tree_data = tree:data()
    if tree_data.type == "test" then
      local package = M.get_package_for_position(tree_data, golist_data)
      if package then
        local test_name = M.extract_test_name_from_position(tree_data)
        if test_name then
          local test_id = M.build_test_identifier(package, test_name)
          lookup[test_id] = tree_data.id
          lookup[test_name] = tree_data.id
          logger.debug("Single test lookup: " .. test_name .. " -> " .. tree_data.id)
        end
      end
    end
  end
  
  -- Iterate through all test positions in the tree
  if tree.iter_nodes then
    for _, node in tree:iter_nodes() do
      local pos = node:data()
      if pos.type == "test" then
        -- Extract package and test name from position
        local package = M.get_package_for_position(pos, golist_data)
        if package then
          -- Handle both regular tests and subtests
          local test_name = M.extract_test_name_from_position(pos)
          if test_name then
            local test_id = M.build_test_identifier(package, test_name)
            lookup[test_id] = pos.id
            
            -- Also add without package for simpler matching
            lookup[test_name] = pos.id
            
            -- For subtests with quotes in the position name, also add unquoted version
            -- This helps match "TestName/Subtest1" from Go with positions like TestName::"Subtest1"
            if pos.name and pos.name:match('^".*"$') then
              local unquoted_name = pos.name:gsub('^"', ''):gsub('"$', '')
              local parent_parts = vim.split(pos.id, "::")
              if #parent_parts >= 3 then
                -- Get parent test name
                local parent_test = M.extract_test_name_from_position({
                  id = table.concat({parent_parts[1], parent_parts[2]}, "::")
                })
                if parent_test then
                  local subtest_name = parent_test .. "/" .. unquoted_name
                  lookup[subtest_name] = pos.id
                  if package then
                    lookup[package .. "::" .. subtest_name] = pos.id
                  end
                  logger.debug("Subtest lookup: " .. subtest_name .. " -> " .. pos.id)
                end
              end
            end
            
            logger.debug("Position lookup: " .. test_id .. " -> " .. pos.id)
            logger.debug("Position lookup: " .. test_name .. " -> " .. pos.id)
          end
        end
      end
    end
  end
  
  local count = vim.tbl_count(lookup)
  logger.debug("Built position lookup with " .. count .. " entries")
  
  return lookup
end

--- Try to find a position by matching test name patterns
--- @param tree neotest.Tree
--- @param package string
--- @param test_name string
--- @return string|nil Position ID if found
function M.find_position_by_test_name(tree, package, test_name)
  -- Handle subtests by checking if test_name contains /
  local main_test, sub_test = test_name:match("^([^/]+)/(.+)$")
  
  if tree.iter_nodes then
    for _, node in tree:iter_nodes() do
      local pos = node:data()
      if pos.type == "test" then
        local pos_test_name = M.extract_test_name_from_position(pos)
        
        -- Direct match
        if pos_test_name == test_name then
          return pos.id
        end
        
        -- Subtest match - check various patterns
        if main_test and sub_test then
          -- Check if this position is the exact subtest
          if pos_test_name == test_name then
            return pos.id
          end
          
          -- Check if position name matches the subtest (with or without quotes)
          if pos.name == '"' .. sub_test .. '"' or pos.name == sub_test then
            -- Verify it's under the right parent test
            if pos.id:match("::" .. main_test .. "::") then
              return pos.id
            end
          end
        end
        
        -- Try matching just the test name without package
        if pos.name == test_name or (main_test and pos.name == main_test) then
          return pos.id
        end
      end
    end
  end
  
  return nil
end

--- Find position ID for a test using multiple strategies
--- @param position_lookup table<string, string> Pre-built lookup table
--- @param tree neotest.Tree
--- @param package string|nil
--- @param test_name string
--- @return string|nil Position ID if found
function M.find_position_id(position_lookup, tree, package, test_name)
  -- Build full test identifier
  local test_id = M.build_test_identifier(package, test_name)
  local pos_id = position_lookup[test_id]
  
  if not pos_id and test_name then
    -- Try multiple strategies to find the position
    -- 1. Try with just the test name
    pos_id = position_lookup[test_name]
    
    -- 2. For subtests, try different formats
    if not pos_id and test_name:match("/") then
      -- Try replacing / with :: for quoted subtests
      local alt_name = test_name:gsub("/", '::')
      pos_id = position_lookup[alt_name]
      
      if not pos_id then
        -- Try with quotes around subtest name
        local parent, subtest = test_name:match("^([^/]+)/(.+)$")
        if parent and subtest then
          local quoted_name = parent .. '::"' .. subtest .. '"'
          pos_id = position_lookup[quoted_name]
        end
      end
    end
    
    -- 3. Try to find position by partial match for subtests
    if not pos_id then
      pos_id = M.find_position_by_test_name(tree, package, test_name)
    end
  end
  
  if not pos_id then
    -- Can't map to a position, log for debugging
    logger.debug("Could not find position for test: " .. (test_name or "unknown") .. " in package: " .. (package or "unknown"))
    return nil
  end
  
  logger.debug("Mapped test '" .. test_name .. "' to position: " .. pos_id)
  return pos_id
end

--- Resolve Go package and test name for a neotest position
--- Used by process.lua for matching test output to positions
--- @param pos neotest.Position
--- @param gotest_output table
--- @param golist_output table
--- @return string|nil, string|nil package, test_name
function M.resolve_package_and_test_name(pos, gotest_output, golist_output)
  local folderpath = vim.fn.fnamemodify(pos.path, ":h")
  local tweaked_pos_id = pos.id:gsub(" ", "_")
  tweaked_pos_id = tweaked_pos_id:gsub('"', "")
  tweaked_pos_id = tweaked_pos_id:gsub("::", "/")

  for _, golistline in ipairs(golist_output) do
    if folderpath == golistline.Dir then
      for _, gotestline in ipairs(gotest_output) do
        if gotestline.Action == "run" and gotestline.Test ~= nil then
          if gotestline.Package == golistline.ImportPath then
            local pattern = lib.convert.to_lua_pattern(folderpath)
              .. lib.find.os_path_sep
              .. "(.-)"
              .. "/"
              .. lib.convert.to_lua_pattern(gotestline.Test)
              .. "$"
            local match = tweaked_pos_id:find(pattern, 1, false)

            if match ~= nil then
              return gotestline.Package, gotestline.Test
            end
          end
        end
      end
    end
  end

  return nil, nil
end

return M