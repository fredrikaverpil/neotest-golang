--- Helpers to build the command and context around running a single test.

local dap = require("neotest-golang.features.dap")
local extra_args = require("neotest-golang.extra_args")
local lib = require("neotest-golang.lib")
local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")

local M = {}

--- Build runspec for a single test
--- @param pos neotest.Position
--- @param strategy string
--- @param tree neotest.Tree|nil Optional tree for streaming support
--- @return neotest.RunSpec | neotest.RunSpec[] | nil
function M.build(pos, strategy, tree)
  local pos_path_folderpath = vim.fn.fnamemodify(pos.path, ":h")

  local golist_data, golist_error = lib.cmd.golist_data(pos_path_folderpath)

  local errors = nil
  if golist_error ~= nil then
    if errors == nil then
      errors = {}
    end
    table.insert(errors, golist_error)
  end

  local test_name = lib.convert.to_gotest_test_name(pos.id)
  local test_name_regex = lib.convert.to_gotest_regex_pattern(test_name)

  local test_cmd, json_filepath = lib.cmd.test_command_in_package_with_regexp(
    pos_path_folderpath,
    test_name_regex
  )

  local runspec_strategy = nil
  if strategy == "dap" then
    dap.assert_dap_prerequisites()
    runspec_strategy = dap.get_dap_config(pos_path_folderpath, test_name_regex)
    logger.debug("DAP strategy used: " .. vim.inspect(runspec_strategy))
    dap.setup_debugging(pos_path_folderpath)
  end

  local env = extra_args.get().env or options.get().env
  if type(env) == "function" then
    env = env()
  end

  --- @type RunspecContext
  local context = {
    pos_id = pos.id,
    golist_data = golist_data,
    errors = errors,
    process_test_results = true,
    test_output_json_filepath = json_filepath,
  }

  --- @type neotest.RunSpec
  local run_spec = {
    command = test_cmd,
    cwd = pos_path_folderpath,
    context = context,
    env = env,
  }

  if runspec_strategy ~= nil then
    run_spec.strategy = runspec_strategy
    run_spec.context.is_dap_active = true
  end

  -- Add streaming support for non-DAP strategies (only works with 'go' runner)
  local streaming_enabled = options.get().experimental_streaming
  if type(streaming_enabled) == "function" then
    streaming_enabled = streaming_enabled()
  end
  
  -- Streaming only works with 'go test -json', not with gotestsum
  local runner = options.get().runner
  if runner == "gotestsum" then
    logger.debug("Streaming disabled: gotestsum writes JSON to file, not stdout")
    streaming_enabled = false
  end
  
  if streaming_enabled and strategy ~= "dap" then
    logger.debug("Streaming enabled for test runspec, tree provided: " .. tostring(tree ~= nil))
    context.is_streaming_active = true
    
    -- For single test, create a minimal tree if not provided
    local stream_tree = tree
    if not stream_tree then
      -- Create a minimal tree with just this test
      stream_tree = {
        iter_nodes = function()
          return function() end
        end,
        data = function()
          return pos
        end
      }
    end
    
    local stream = require("neotest-golang.lib.stream")
    local parser = stream.new(stream_tree, golist_data)
    local accumulated_results = {}
    
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
  end

  logger.debug({ "RunSpec:", run_spec })
  return run_spec
end

return M
