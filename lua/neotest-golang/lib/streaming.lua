--- Common streaming functionality for neotest-golang.
---
--- This module consolidates all streaming setup logic used across runspecs,
--- providing a unified interface for enabling real-time test result streaming.
---
--- Key features:
--- - Centralized streaming compatibility checks (strategy, runner)
--- - Unified stream parser setup and configuration
--- - Support for both regular and single-test streaming scenarios
--- - Automatic fallback when streaming is not supported
--- - Consistent streaming behavior across all runspec types

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

  -- Streaming now works with both 'go test -json' and gotestsum
  return true
end

--- Check if streaming is enabled in options
--- @return boolean
function M.is_streaming_enabled()
  local streaming_enabled = options.get().stream_enabled
  if type(streaming_enabled) == "function" then
    streaming_enabled = streaming_enabled()
  end
  return streaming_enabled or false
end

--- Setup file-based streaming for gotestsum
--- @param run_spec neotest.RunSpec The runspec to modify
--- @param json_filepath string The JSON file path to stream from
--- @param tree neotest.Tree|nil The test tree (required for streaming)
--- @param golist_data table The golist data
--- @param context table The runspec context to modify
--- @param strategy string|nil Optional strategy (e.g., "dap")
--- @return neotest.RunSpec The modified runspec
function M.setup_gotestsum_file_streaming(
  run_spec,
  json_filepath,
  tree,
  golist_data,
  context,
  strategy
)
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

  if not json_filepath then
    logger.debug("Streaming disabled: no JSON file path provided")
    return run_spec
  end

  logger.debug("Setting up gotestsum file streaming for: " .. json_filepath)
  logger.warn("🚀 GOTESTSUM STREAMING SETUP STARTED - Runner: " .. runner)
  context.is_streaming_active = true

  -- Create stream parser
  local stream = require("neotest-golang.lib.stream")
  local parser = stream.new(tree, golist_data)
  local accumulated_results = {}

  -- Set up gotestsum file streaming using the correct neotest.lib access
  logger.warn("🔧 SETTING UP GOTESTSUM FILE STREAMING")
  
  -- Access neotest.lib.files through the official API
  local neotest_lib = require("neotest.lib")
  local neotest_files = neotest_lib.files
  
  logger.warn("✅ neotest.lib.files accessed successfully")
  
  -- Add stream function that sets up file streaming lazily
  run_spec.stream = function(data)
    logger.warn("📡 GOTESTSUM STREAM FUNCTION SETUP")
    
    -- Lazy initialization of file streaming
    local stream_lines, stop_stream
    local file_streaming_initialized = false
    
    -- Return the actual stream function that neotest will call repeatedly
    return function()
      logger.warn("🔄 GOTESTSUM STREAM FUNCTION CALLED")
      
      -- Initialize file streaming on first call (when file should exist)
      if not file_streaming_initialized then
        logger.warn("🔧 Initializing file streaming for: " .. json_filepath)
        
        -- Check if file exists (non-blocking)
        if vim.fn.filereadable(json_filepath) == 1 then
          logger.warn("✅ JSON file found, setting up streaming: " .. json_filepath)
          
          -- Try to set up file streaming
          local stream_ok, stream_err = pcall(function()
            stream_lines, stop_stream = neotest_files.stream_lines(json_filepath)
          end)
          
          if stream_ok then
            logger.warn("✅ File streaming initialized successfully")
            file_streaming_initialized = true
          else
            logger.warn("❌ Failed to set up file streaming: " .. tostring(stream_err))
            return accumulated_results
          end
        else
          logger.warn("⏳ JSON file not ready yet: " .. json_filepath)
          return accumulated_results
        end
      end
      
      -- Process lines from file stream
      if not stream_lines then
        return accumulated_results
      end
      
      local lines
      local stream_ok, stream_err = pcall(function()
        lines = stream_lines()
      end)

      if not stream_ok then
        logger.warn("❌ Error reading from file stream: " .. tostring(stream_err))
        return accumulated_results
      end

      if not lines then
        logger.warn("📭 No lines received from stream")
        return accumulated_results
      end

      if #lines > 0 then
        logger.warn("📝 Received " .. #lines .. " lines from stream")
        local parse_ok, new_results = pcall(function()
          return parser:process_lines(lines)
        end)

        if parse_ok and new_results then
          for pos_id, result in pairs(new_results) do
            accumulated_results[pos_id] = result
          end
        elseif not parse_ok then
          logger.warn("❌ Error processing stream lines: " .. tostring(new_results))
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
    end,
  }
end

--- Setup gotestsum file streaming for a single test with optional tree creation
--- @param run_spec neotest.RunSpec The runspec to modify
--- @param json_filepath string The JSON file path to stream from
--- @param tree neotest.Tree|nil The test tree (will create minimal if nil)
--- @param golist_data table The golist data
--- @param context table The runspec context to modify
--- @param pos neotest.Position The test position (used if tree is nil)
--- @param strategy string|nil Optional strategy (e.g., "dap")
--- @return neotest.RunSpec The modified runspec
function M.setup_gotestsum_file_streaming_for_single_test(
  run_spec,
  json_filepath,
  tree,
  golist_data,
  context,
  pos,
  strategy
)
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

  logger.debug(
    "Setting up gotestsum file streaming for single test, tree provided: "
      .. tostring(tree ~= nil)
  )

  return M.setup_gotestsum_file_streaming(
    run_spec,
    json_filepath,
    stream_tree,
    golist_data,
    context,
    strategy
  )
end

--- Setup streaming for a single test with optional tree creation
--- @param run_spec neotest.RunSpec The runspec to modify
--- @param tree neotest.Tree|nil The test tree (will create minimal if nil)
--- @param golist_data table The golist data
--- @param context table The runspec context to modify
--- @param pos neotest.Position The test position (used if tree is nil)
--- @param strategy string|nil Optional strategy (e.g., "dap")
--- @return neotest.RunSpec The modified runspec
function M.setup_streaming_for_single_test(
  run_spec,
  tree,
  golist_data,
  context,
  pos,
  strategy
)
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

  logger.debug(
    "Setting up streaming for single test, tree provided: "
      .. tostring(tree ~= nil)
  )

  return M.setup_streaming(
    run_spec,
    stream_tree,
    golist_data,
    context,
    strategy
  )
end

return M
