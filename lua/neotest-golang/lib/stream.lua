--- Streaming JSON parser for go test output.
--- Processes go test -json output incrementally and converts to neotest results.

local logger = require("neotest-golang.logging")
local position_resolver = require("neotest-golang.lib.position_resolver")

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
  parser.position_lookup = position_resolver.build_position_lookup(tree, golist_data)

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
    

    
    -- Find position ID using unified resolver
    local pos_id = position_resolver.find_position_id(self.position_lookup, self.tree, package, test_name)
    
    if not pos_id then
      return nil
    end
    
    -- Cache the lookup for future events
    local test_id = position_resolver.build_test_identifier(package, test_name)
    if test_id then
      self.position_lookup[test_id] = pos_id
    end
    if test_name then
      self.position_lookup[test_name] = pos_id
    end
    
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
