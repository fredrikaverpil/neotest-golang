--- Lookup table for renaming Neotest namespaces (receiver type to testify suite function).

local options = require("neotest-golang.options")
local query = require("neotest-golang.features.testify.query")
local query_loader = require("neotest-golang.lib.query_loader")

---@class TestifyMethodInstance
---@field receiver string The receiver type (e.g., "MySuite", "*MySuite")
---@field definition table Tree-sitter match object containing the method definition
---@field source_file string Absolute path to the file where this method is defined

---@class TestifyFileData
---@field package string The Go package name
---@field replacements table<string, string> Map of receiver type to suite function name (e.g., {"MySuite" -> "TestMySuite"})
---@field methods table<string, TestifyMethodInstance[]> Map of method name to list of method instances (supports multiple receivers with same method name)

---@class TestifyLookupTable
---@field [string] TestifyFileData Map of file path to file data

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

--- Initialize the lookup table for all test files in the given paths
---@param file_paths string[] List of file paths to process
---@return TestifyLookupTable The initialized lookup table
M.initialize_lookup = lookup_manager.init

--- Create or update lookup data for a single file
---@param file_path string The file path to process
---@return TestifyLookupTable The updated lookup table
M.create_lookup = lookup_manager.create

--- Get the current lookup table
---@return TestifyLookupTable The current lookup table
M.get_lookup = lookup_manager.get

--- Clear the lookup table
M.clear_lookup = lookup_manager.clear

--- Generate the lookup data for the given file.
---@param file_path string The file path to analyze
---@return TestifyFileData The generated file data
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
      data.replacements[struct.text] = func.text
    end
  end

  -- Second pass: collect method information for cross-file support
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
          if not data.methods[method_name] then
            data.methods[method_name] = {}
          end
          table.insert(data.methods[method_name], {
            receiver = receiver_match.text,
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
