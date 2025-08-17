local json = require("neotest-golang.lib.json")
local logger = require("neotest-golang.logging")
local mapping = require("neotest-golang.lib.mapping")
local options = require("neotest-golang.options")

local neotest_lib = require("neotest.lib")

local M = {}

M.cached_results = {}

--- Contstructor for new stream.
--- @param golist_data table Golist data containing package information
---@param json_filepath string|nil Path to the JSON output file
---@return function, function
function M.new(tree, golist_data, json_filepath)
  M.cached_results = {} -- reset
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
    local process = require("neotest-golang.process") -- TODO: fix circular dependency
    local json_lines = {}
    local accum = {}
    ---@type table<string, neotest.Result>
    local results = {}

    -- Build position lookup table once for O(1) mapping performance
    local position_lookup = mapping.build_position_lookup(tree, golist_data)
    logger.debug(
      "Built position lookup with "
        .. vim.tbl_count(position_lookup)
        .. " mappings"
    )

    return function()
      local lines = {}
      if options.get().runner == "go" then
        lines = data() -- capture from stdout
      elseif options.get().runner == "gotestsum" then
        lines = stream_data() -- capture from stream
      end

      json_lines = json.decode_from_table(lines, true)

      for _, json_line in ipairs(json_lines) do
        accum = process.process_event(
          tree,
          golist_data,
          accum,
          json_line,
          position_lookup
        )
      end

      results = process.make_results(accum)

      -- Populate file nodes with aggregated results during streaming (simple approach)
      results = process.populate_file_nodes(tree, results)

      for pos_id, result in pairs(results) do
        M.cached_results[pos_id] = result
      end

      return results
    end
  end

  return stream, stop_stream
end

return M
