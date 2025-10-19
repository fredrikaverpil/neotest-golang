--- Lookup table for mapping testify receiver methods to their suite functions (flat structure).

local options = require("neotest-golang.options")
local query = require("neotest-golang.features.testify.query")
local query_loader = require("neotest-golang.lib.query_loader")

local M = {}

-- TreeSitter query for identifying testify suites and their components.
-- Below, queries for the lookup between receiver and test suite.

M.package_query =
  query_loader.load_query("features/testify/queries/go/package.scm")

M.suite_query = string.format(
  query_loader.load_query("features/testify/queries/go/suite.scm"),
  options.get().testify_import_identifier
)

M.test_function_query = string.format(
  query_loader.load_query("features/testify/queries/go/test_function.scm"),
  options.get().testify_import_identifier
)

local function create_lookup_manager()
  local lookup_table = {}

  return {
    init = function(file_paths)
      for _, file_path in ipairs(file_paths) do
        lookup_table[file_path] = M.generate_data(file_path)
      end
      return lookup_table
    end,
    create = function(file_path)
      lookup_table[file_path] = M.generate_data(file_path)
      return lookup_table
    end,
    get = function()
      return lookup_table
    end,
    clear = function()
      lookup_table = {}
    end,
  }
end

-- Create an instance of the lookup manager
local lookup_manager = create_lookup_manager()

--- Public lookup functions.
M.initialize_lookup = lookup_manager.init
M.create_lookup = lookup_manager.create
M.get_lookup = lookup_manager.get
M.clear_lookup = lookup_manager.clear

--- Generate the lookup data for the given file.
--- @return table<string, table> The generated lookup table
function M.generate_data(file_path)
  local data = {}

  -- First pass: collect all data for the lookup table.
  local queries = M.package_query .. M.suite_query .. M.test_function_query
  local matches = query.run_query_on_file(file_path, queries)

  local package_name = matches.package
      and matches.package[1]
      and matches.package[1].text
    or "unknown"

  data = {
    package = package_name,
    replacements = {},
    methods = {}, -- Add methods collection
  }

  for i, struct in ipairs(matches.suite_struct or {}) do
    local func = matches.test_function[i]
    if func then
      -- Use package-qualified receiver type to avoid collisions across packages
      local qualified_receiver = package_name .. "." .. struct.text
      data.replacements[qualified_receiver] = func.text
    end
  end

  -- Second pass: collect method information from receiver functions
  -- Run namespace query to find all receiver methods in this file
  local namespace_matches =
    query.run_query_on_file(file_path, query.namespace_query)

  if
    namespace_matches.namespace_name and namespace_matches.namespace_definition
  then
    for i, receiver_match in ipairs(namespace_matches.namespace_name) do
      local definition_match = namespace_matches.namespace_definition[i]
      if definition_match then
        -- Extract method name from the definition
        local method_name =
          definition_match.text:match("func %([^)]+%) ([%w_]+)%(")
        if method_name then
          -- Store method info: name -> {receiver, definition, source_file}
          -- Use package-qualified receiver to avoid collisions
          if not data.methods[method_name] then
            data.methods[method_name] = {}
          end
          local qualified_receiver = package_name .. "." .. receiver_match.text
          table.insert(data.methods[method_name], {
            receiver = qualified_receiver,
            definition = definition_match,
            source_file = file_path,
          })
        end
      end
    end
  end

  return data
end

return M
