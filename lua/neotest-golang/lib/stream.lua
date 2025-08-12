local convert = require("neotest-golang.lib.convert")
local json = require("neotest-golang.lib.json")
local logger = require("neotest-golang.logging")
local options = require("neotest-golang.options")

local async = require("neotest.async")
local neotest_lib = require("neotest.lib")

local M = {}

--- Convert to internal and unique test id for lookup.
local function to_test_id(package_name, test_name)
  return package_name .. "::" .. test_name
end

--- Contstructor for new stream.
--- @param golist_data table Golist data containing package information
---@param json_filepath string|nil Path to the JSON output file
---@return function, function
function M.new(tree, golist_data, json_filepath)
  -- vim.notify(vim.inspect("New stream!"))

  M.accumulated_test_data = {} -- reset
  local stream_data = function() end -- no-op
  local stop_stream = function() end -- no-op
  if options.get().runner == "gotestsum" then
    if json_filepath ~= nil then
      neotest_lib.files.write(json_filepath, "") -- ensure the file exists
      stream_data, stop_stream = neotest_lib.files.stream_lines(json_filepath)
    else
      logger.error("JSON filepath is required for gotestsum runner streaming")
    end
  end

  --- Stream function.
  ---@param data function A function that returns a table of strings, each representing a line of JSON output.
  local function stream(data)
    local tree = tree
    local golist_data = golist_data
    local json_lines = {}
    local accum = {}

    ---@type table<string, neotest.Result>
    local results = {}

    return function()
      local lines = {}
      if options.get().runner == "go" then
        lines = data() -- capture from stdout
      elseif options.get().runner == "gotestsum" then
        lines = stream_data() -- capture from stream
      end

      for _, line in ipairs(lines) do
        json_lines = vim.list_extend(json_lines, json.decode_from_string(line))
        for _, json_line in ipairs(json_lines) do
          accum = M.process_event(tree, golist_data, accum, json_line)
        end
      end

      for _, test_data in pairs(accum) do
        if test_data.position_id ~= nil then
          -- NOTE: for faster feedback, do not write output yet?
          -- local o = vim.split(test_data.output, "\n", { trimempty = true })
          -- async.fn.writefile(o, test_data.output_path)

          results[test_data.position_id] = {
            status = test_data.status,
            -- output = test_data.output_path,
            -- TODO: add short
            -- TODO: add errors
          }
        end
      end

      -- TODO: only return a result when a test has a status (pass/fail/skip), otherwise return {}
      return results
    end
  end

  return stream, stop_stream
end

-- Find position id in neotest tree, given pattern.
---@param tree neotest.Tree The Neotest tree structure
---@param test_pattern string The pattern to match against position ids
---@return string|nil The position id, if any.
function M.find_position_id_for_test(tree, test_pattern)
  -- Search the tree for matching position id
  for _, node in tree:iter_nodes() do
    --- @type neotest.Position
    local pos = node:data()

    -- Test pattern:
    -- {
    --   id = '/Users/fredrik/code/public/someproject/internal/foo/bar/baz_test.go::TestName::"SubTestName"',
    --   name = '"SubTestName"',
    --   path = "/Users/fredrik/code/public/someproject/internal/foo/bar/baz_test.go",
    --   range = { 11, 1, 28, 3 },
    --   type = "test"
    -- }
    if pos.id:match(test_pattern) and pos.type == "test" then
      return pos.id
    end

    -- Namespace pattern:
    -- (same as test pattern?)

    -- File pattern:
    -- {
    --   id = "/Users/fredrik/code/public/someproject/internal/foo/bar/baz_test.go",
    --   name = "baz_test.go",
    --   path = "/Users/fredrik/code/public/someproject/internal/foo/bar/baz_test.go",
    --   range = { 0, 0, 30, 0 },
    --   type = "file"
    -- }
    -- local file_pattern = pattern:match("^(.-)::")
    -- if pos.id:match(file_pattern) and pos.type == "file" then
    --   return pos.id
    -- end

    -- Dir pattern:
    -- {
    --   id = "/Users/fredrik/code/public/someproject/internal/foo/bar",
    --   name = "bar",
    --   path = "/Users/fredrik/code/public/someproject/internal/foo/bar",
    --   type = "dir"
    -- }
    --   local file_path = pattern:match("^(.-)::")
    --   local dir_pattern = file_path and file_path:match("(.+)/[^/]+$")
    --   if dir_pattern and pos.id:match(dir_pattern) and pos.type == "dir" then
    --     return pos.id
    --   end
  end
end

--- Process a single event from the test output.
--- @param accum table Accumulated test data.
--- @param e table The event data.
function M.process_event(tree, golist_data, accum, e)
  -- TODO: do we want to do something with 'start' status?

  -- Indicate test started/running.
  if e.Action == "run" and e.Package ~= nil and e.Test ~= nil then
    local id = to_test_id(e.Package, e.Test)
    accum[id] = { status = "running", output = "" }
    if e.Output ~= nil then
      accum[id].output = e.Output
    end
  end

  -- Record output for test.
  if
    e.Action == "output"
    and e.Package ~= nil
    and e.Test ~= nil
    and e.Output ~= nil
  then
    local id = to_test_id(e.Package, e.Test)
    accum[id].output = accum[id].output .. e.Output
  end

  -- Register passing test.
  if
    (e.Action == "pass" or e.Action == "fail" or e.Action == "skip")
    and e.Package ~= nil
    and e.Test ~= nil
  then
    local id = to_test_id(e.Package, e.Test)
    if e.Action == "pass" then
      accum[id].status = "passed"
    elseif e.Action == "fail" then
      accum[id].status = "failed"
    else
      accum[id].status = "skipped"
    end
    if e.Output ~= nil then
      accum[id].output = accum[id].output .. e.Output
    end

    accum[id].output_path = vim.fs.normalize(async.fn.tempname())

    local pattern =
      convert.to_test_position_id_pattern(golist_data, e.Package, e.Test)
    if pattern then
      local pos_id = M.find_position_id_for_test(tree, pattern)
      if pos_id then
        accum[id].position_id = pos_id
      else
        logger.debug(
          "Unable to find position id for passed test: "
            .. e.Package
            .. "::"
            .. e.Test
        )
      end
    else
      logger.error(
        "Could not find position id pattern for test: "
          .. e.Test
          .. " in package: "
          .. e.Package
      )
    end
  end

  -- Indicate package started/running.
  if e.Action == "start" and e.Package ~= nil and e.Test == nil then
    local id = e.Package
    accum[id] = { status = "running", output = "" }
    if e.Output ~= nil then
      accum[id].output = e.Output
    end
  end

  -- Record output for package.
  if e.Action == "output" and e.Package ~= nil and e.Test == nil then
    local id = e.Package
    if e.Output ~= nil then
      accum[id].output = accum[id].output .. e.Output
    end
  end

  -- Register passing package.
  if
    (e.Action == "pass" or e.Action == "fail" or e.Action == "skip")
    and e.Package ~= nil
    and e.Test == nil
  then
    local id = e.Package
    if e.Action == "pass" then
      accum[id].status = "passed"
    elseif e.Action == "fail" then
      accum[id].status = "failed"
    else
      accum[id].status = "skipped"
    end
    accum[id].position_id = convert.to_dir_position_id(golist_data, e.Package)
    if e.Output ~= nil then
      accum[id].output = accum[id].output .. e.Output
    end

    accum[id].output_path = vim.fs.normalize(async.fn.tempname())
  end

  return accum
end

return M
