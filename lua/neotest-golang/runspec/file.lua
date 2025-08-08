--- Helpers to build the command and context around running all tests of a file.

local dap = require("neotest-golang.features.dap")
local extra_args = require("neotest-golang.extra_args")
local lib = require("neotest-golang.lib")
local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")

local M = {}

--- Build runspec for a file.
--- @param pos neotest.Position
--- @param tree neotest.Tree
--- @param strategy string
--- @return neotest.RunSpec | neotest.RunSpec[] | nil
function M.build(pos, tree, strategy)
  if vim.tbl_isempty(tree:children()) then
    logger.warn("No tests found in file")
    return M.return_skipped(pos)
  end

  local go_mod_filepath = lib.find.file_upwards("go.mod", pos.path)
  if go_mod_filepath == nil then
    logger.error(
      "The selected file does not appear to be part of a valid Go module (no go.mod file found)."
    )
    return nil -- NOTE: logger.error will throw an error, but the LSP doesn't see it.
  end

  local go_mod_folderpath = vim.fn.fnamemodify(go_mod_filepath, ":h")
  local pos_path_folderpath = vim.fn.fnamemodify(pos.path, ":h")
  local golist_data, golist_error = lib.cmd.golist_data(pos_path_folderpath)

  local errors = nil
  if golist_error ~= nil then
    if errors == nil then
      errors = {}
    end
    table.insert(errors, golist_error)
  end

  -- find the go package that corresponds to the pos.path
  local package_name = "./..."
  local pos_path_filename = vim.fn.fnamemodify(pos.path, ":t")

  for _, golist_item in ipairs(golist_data) do
    if golist_item.TestGoFiles ~= nil then
      if
        pos_path_folderpath == golist_item.Dir
        and vim.tbl_contains(golist_item.TestGoFiles, pos_path_filename)
      then
        package_name = golist_item.ImportPath
        break
      end
    end
    if golist_item.XTestGoFiles ~= nil then
      -- NOTE: XTestGoFiles are test files that are part of a [packagename]_test package.
      if
        pos_path_folderpath == golist_item.Dir
        and vim.tbl_contains(golist_item.XTestGoFiles, pos_path_filename)
      then
        package_name = golist_item.ImportPath
        break
      end
    end
  end

  -- find all top-level tests in pos.path
  local test_cmd = nil
  local json_filepath = nil
  local regexp = M.get_regexp(pos.path)
  if regexp ~= nil then
    test_cmd, json_filepath =
      lib.cmd.test_command_in_package_with_regexp(package_name, regexp)
  else
    -- fallback: run all tests in the package
    test_cmd, json_filepath = lib.cmd.test_command_in_package(package_name)
    -- NOTE: could also fall back to running on a per-test basis by using a bare return
  end

  local runspec_strategy = nil
  if strategy == "dap" then
    dap.assert_dap_prerequisites()
    runspec_strategy = dap.get_dap_config(pos_path_folderpath, regexp)
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
    logger.debug(
      "Streaming disabled: gotestsum writes JSON to file, not stdout"
    )
    streaming_enabled = false
  end

  if streaming_enabled and strategy ~= "dap" then
    logger.info("Streaming enabled for file runspec with runner: " .. runner)
    local stream = require("neotest-golang.lib.stream")
    local parser = stream.new(tree, golist_data)
    context.is_streaming_active = true
    -- The stream function should return a function that processes chunks
    -- Create a fresh parser for streaming
    local accumulated_results = {}
    
    run_spec.stream = function(data)
      -- Return a function that will be called repeatedly by Neotest
      return function()
        -- Call data() to get lines - this should give us new lines each time
        local lines = data()
        
        if not lines then
          return accumulated_results  -- Return final accumulated results
        end
        
        -- Process the new lines
        if #lines > 0 then
          local new_results = parser:process_lines(lines)
          
          -- Accumulate results
          if new_results then
            for pos_id, result in pairs(new_results) do
              accumulated_results[pos_id] = result
            end
          end
          
          -- Always return the accumulated results so far
          if next(accumulated_results) then
            return accumulated_results
          end
        end
        
        return {}  -- Return empty table to indicate we're still processing
      end
    end
  else
    logger.info(
      "Streaming NOT enabled. Enabled="
        .. tostring(streaming_enabled)
        .. ", Strategy="
        .. tostring(strategy)
        .. ", Runner="
        .. tostring(runner)
    )
  end

  logger.debug({ "RunSpec:", run_spec })
  return run_spec
end

function M.return_skipped(pos)
  --- @type RunspecContext
  local context = {
    pos_id = pos.id,
    golist_data = {}, -- no golist output
  }

  --- Runspec designed for files that contain no tests.
  --- @type neotest.RunSpec
  local run_spec = {
    command = { "echo", "No tests found in file" },
    context = context,
  }
  return run_spec
end

function M.get_regexp(filepath)
  local regexp = nil
  local lines = {}
  for line in io.lines(filepath) do
    if line:match("func Test") then
      line = line:gsub("func ", "")
      line = line:gsub("%(.*", "")
      table.insert(lines, lib.convert.to_gotest_regex_pattern(line))
    end
  end
  if #lines > 0 then
    regexp = "^(" .. table.concat(lines, "|") .. ")$"
  end
  return regexp
end

return M
