--- Streaming JSON parser for go test output.
--- Processes go test -json output incrementally and converts to neotest results.

local logger = require("neotest-golang.logging")

local M = {}

--- Create a new streaming parser instance
--- @param tree neotest.Tree The test tree to map positions
--- @param golist_data table The go list data for package information
--- @return table Parser instance
function M.new(tree, golist_data)
  local parser = {
    tree = tree,
    golist_data = golist_data,
    partial_output = {}, -- Buffer for incomplete JSON lines
    test_outputs = {}, -- Accumulated output per test
    test_statuses = {}, -- Track test statuses
    position_lookup = {}, -- Map from go test names to position IDs
  }

  -- Build position lookup table
  parser.position_lookup = M.build_position_lookup(tree, golist_data)

  --- Process incoming data lines
  --- @param lines string[] Array of output lines
  --- @return table<string, neotest.Result> Partial results
  function parser:process_lines(lines)
    local results = {}
    
    logger.debug("Stream parser: Processing " .. #lines .. " lines")
    
    for _, line in ipairs(lines) do
      -- Skip empty lines
      if line and line ~= "" then
        -- Try to parse as JSON
        local ok, event = pcall(vim.json.decode, line)
        if ok and event then
          logger.debug("Stream parser: Parsed event - Action=" .. (event.Action or "unknown") .. ", Test=" .. (event.Test or "none"))
          local result = self:process_event(event)
          if result then
            logger.debug("Stream parser: Generated results for " .. vim.inspect(vim.tbl_keys(result)))
            for pos_id, res in pairs(result) do
              results[pos_id] = res
            end
          end
        else
          -- If not valid JSON, might be partial line - buffer it
          table.insert(self.partial_output, line)
          
          -- Try to combine buffered lines
          local combined = table.concat(self.partial_output, "")
          ok, event = pcall(vim.json.decode, combined)
          if ok and event then
            self.partial_output = {}
            local result = self:process_event(event)
            if result then
              for pos_id, res in pairs(result) do
                results[pos_id] = res
              end
            end
          elseif #self.partial_output > 10 then
            -- Clear buffer if it gets too large (likely not JSON)
            logger.debug("Clearing partial output buffer: " .. table.concat(self.partial_output, ""))
            self.partial_output = {}
          end
        end
      end
    end
    
    return results
  end

  --- Process a single go test JSON event
  --- @param event table The parsed JSON event
  --- @return table<string, neotest.Result>|nil
  function parser:process_event(event)
    local action = event.Action
    local test_name = event.Test
    local package = event.Package
    
    if not action then
      return nil
    end
    
    -- Skip package-level events (no test name)
    if not test_name then
      -- Could handle package start/fail events here if needed
      return nil
    end
    

    
    -- Build full test identifier
    local test_id = M.build_test_identifier(package, test_name)
    local pos_id = self.position_lookup[test_id]
    
    if not pos_id and test_name then
      -- Try multiple strategies to find the position
      -- 1. Try with just the test name
      pos_id = self.position_lookup[test_name]
      
      -- 2. For subtests, try different formats
      if not pos_id and test_name:match("/") then
        -- Try replacing / with :: for quoted subtests
        local alt_name = test_name:gsub("/", '::')
        pos_id = self.position_lookup[alt_name]
        
        if not pos_id then
          -- Try with quotes around subtest name
          local parent, subtest = test_name:match("^([^/]+)/(.+)$")
          if parent and subtest then
            local quoted_name = parent .. '::"' .. subtest .. '"'
            pos_id = self.position_lookup[quoted_name]
          end
        end
      end
      
      -- 3. Try to find position by partial match for subtests
      if not pos_id then
        pos_id = M.find_position_by_test_name(self.tree, package, test_name)
      end
      
      -- Cache the lookup for future events
      if pos_id then
        self.position_lookup[test_id] = pos_id
        self.position_lookup[test_name] = pos_id
      end
    end
    
    if not pos_id then
      -- Can't map to a position, skip but log for debugging
      logger.debug("Could not find position for test: " .. (test_name or "unknown") .. " in package: " .. (package or "unknown"))
      return nil
    end
    
    logger.debug("Mapped test '" .. test_name .. "' to position: " .. pos_id)
    
    -- Initialize output buffer for this test if needed
    if not self.test_outputs[pos_id] then
      self.test_outputs[pos_id] = {}
    end
    
    -- Process based on action type
    if action == "run" then
      -- Test started running
      return {
        [pos_id] = {
          status = "running",
        }
      }
    elseif action == "output" then
      -- Accumulate output
      if event.Output then
        table.insert(self.test_outputs[pos_id], event.Output)
      end
      return nil -- Don't emit result yet
    elseif action == "pass" then
      -- Test passed
      return {
        [pos_id] = {
          status = "passed",
          short = table.concat(self.test_outputs[pos_id] or {}, ""),
        }
      }
    elseif action == "fail" then
      -- Test failed
      local output = table.concat(self.test_outputs[pos_id] or {}, "")
      local errors = M.extract_errors_from_output(output)
      return {
        [pos_id] = {
          status = "failed",
          short = output,
          errors = errors,
        }
      }
    elseif action == "skip" then
      -- Test skipped
      return {
        [pos_id] = {
          status = "skipped",
          short = table.concat(self.test_outputs[pos_id] or {}, ""),
        }
      }
    end
    
    return nil
  end

  return parser
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

--- Extract error information from test output
--- @param output string
--- @return neotest.Error[]
function M.extract_errors_from_output(output)
  local errors = {}
  
  -- Look for failure messages and line numbers in output
  for line in output:gmatch("[^\n]+") do
    -- Skip the RUN and FAIL header lines
    if not line:match("^=== RUN") and not line:match("^--- FAIL") then
      -- Pattern 1: filename.go:line:column: message
      local file, line_num, message = line:match("([^:]+%.go):(%d+):%d*:?%s*(.+)")
      if file and line_num then
        table.insert(errors, {
          message = message or line,
          line = tonumber(line_num) - 1, -- Convert to 0-based
        })
      -- Pattern 2: filename_test.go:line: message (from t.Error/t.Fatal)
      elseif line:match("_test%.go:%d+:") then
        local test_file, test_line, test_msg = line:match("([^:]+):(%d+):%s*(.+)")
        if test_file and test_line then
          table.insert(errors, {
            message = test_msg or line,
            line = tonumber(test_line) - 1,
          })
        end
      -- Pattern 3: Error Trace: ... (from testify)
      elseif line:match("Error Trace:") or line:match("Error:") then
        -- Extract the actual error message
        local error_msg = line:match("Error:%s*(.+)") or line
        table.insert(errors, {
          message = error_msg,
        })
      end
    end
  end
  
  -- If no specific errors found but test failed, extract the failure reason
  if #errors == 0 then
    -- Look for assertion failures or other error indicators
    for line in output:gmatch("[^\n]+") do
      if line:match("expected") or line:match("got") or line:match("want") then
        table.insert(errors, {
          message = vim.trim(line),
        })
        break
      end
    end
    
    -- Still no errors? Add generic message
    if #errors == 0 and output:match("FAIL") then
      table.insert(errors, {
        message = "Test failed - see output for details",
      })
    end
  end
  
  return errors
end

return M
