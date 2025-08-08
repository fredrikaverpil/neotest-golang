--- Common streaming functionality for neotest-golang.
--- Consolidates streaming setup logic used across all runspecs.

local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")

local M = {}

--- Check if streaming is supported for the given strategy and runner
--- @param strategy string|nil The test strategy (e.g., "dap")
--- @param runner string The test runner ("go" or "gotestsum")
--- @return boolean
function M.is_streaming_supported(strategy, runner)
  -- Streaming doesn't work with DAP debugging
  if strategy == "dap" then
    logger.debug("Streaming disabled: DAP strategy not compatible")
    return false
  end
  
  -- Streaming only works with 'go test -json', not with gotestsum
  if runner == "gotestsum" then
    logger.debug("Streaming disabled: gotestsum writes JSON to file, not stdout")
    return false
  end
  
  return true
end

--- Check if streaming is enabled in options
--- @return boolean
function M.is_streaming_enabled()
  local streaming_enabled = options.get().experimental_streaming
  if type(streaming_enabled) == "function" then
    streaming_enabled = streaming_enabled()
  end
  return streaming_enabled or false
end

--- Setup streaming for a runspec
--- @param run_spec neotest.RunSpec The runspec to modify
--- @param tree neotest.Tree|nil The test tree (required for streaming)
--- @param golist_data table The golist data
--- @param context table The runspec context to modify
--- @param strategy string|nil Optional strategy (e.g., "dap")
--- @return neotest.RunSpec The modified runspec
function M.setup_streaming(run_spec, tree, golist_data, context, strategy)
  local streaming_enabled = M.is_streaming_enabled()
  local runner = options.get().runner
  
  if not streaming_enabled then
    logger.debug("Streaming not enabled in options")
    return run_spec
  end
  
  if not tree then
    logger.debug("Streaming disabled: no tree provided")
    return run_spec
  end
  
  if not M.is_streaming_supported(strategy, runner) then
    return run_spec
  end
  
  logger.debug("Setting up streaming for runspec")
  context.is_streaming_active = true
  
  -- Create stream parser
  local stream = require("neotest-golang.lib.stream")
  local parser = stream.new(tree, golist_data)
  local accumulated_results = {}
  
  -- Add stream function to runspec
  run_spec.stream = function(data)
    return function()
      local lines = data()
      
      if not lines then
        return accumulated_results
      end
      
      if #lines > 0 then
        local new_results = parser:process_lines(lines)
        if new_results then
          for pos_id, result in pairs(new_results) do
            accumulated_results[pos_id] = result
          end
        end
        
        if next(accumulated_results) then
          return accumulated_results
        end
      end
      
      return {}
    end
  end
  
  return run_spec
end

--- Create a minimal tree for single test streaming
--- Used when tree is not provided but we need streaming for a single test
--- @param pos neotest.Position The test position
--- @return table Minimal tree structure
function M.create_minimal_tree(pos)
  return {
    iter_nodes = function()
      return function() end
    end,
    data = function()
      return pos
    end
  }
end

--- Setup streaming for a single test with optional tree creation
--- @param run_spec neotest.RunSpec The runspec to modify
--- @param tree neotest.Tree|nil The test tree (will create minimal if nil)
--- @param golist_data table The golist data
--- @param context table The runspec context to modify
--- @param pos neotest.Position The test position (used if tree is nil)
--- @param strategy string|nil Optional strategy (e.g., "dap")
--- @return neotest.RunSpec The modified runspec
function M.setup_streaming_for_single_test(run_spec, tree, golist_data, context, pos, strategy)
  local streaming_enabled = M.is_streaming_enabled()
  local runner = options.get().runner
  
  if not streaming_enabled then
    logger.debug("Streaming not enabled in options")
    return run_spec
  end
  
  if not M.is_streaming_supported(strategy, runner) then
    return run_spec
  end
  
  -- Create minimal tree if not provided
  local stream_tree = tree
  if not stream_tree then
    logger.debug("Creating minimal tree for single test streaming")
    stream_tree = M.create_minimal_tree(pos)
  end
  
  logger.debug("Setting up streaming for single test, tree provided: " .. tostring(tree ~= nil))
  
  return M.setup_streaming(run_spec, stream_tree, golist_data, context, strategy)
end

return M