--- Detect test names in Go *._test.go files.

local lib = require("neotest.lib")

local dupe = require("neotest-golang.lib.dupe")
local logger = require("neotest-golang.lib.logging")
local options = require("neotest-golang.options")
local query_loader = require("neotest-golang.lib.query_loader")
local testify = require("neotest-golang.features.testify")

local M = {}

M.test_function = query_loader.load_query("queries/test_function.scm")

M.table_tests_list = query_loader.load_query("queries/table_tests_list.scm")

M.table_tests_loop = query_loader.load_query("queries/table_tests_loop.scm")

M.table_tests_unkeyed =
  query_loader.load_query("queries/table_tests_unkeyed.scm")

M.table_tests_loop_unkeyed =
  query_loader.load_query("queries/table_tests_loop_unkeyed.scm")

M.table_tests_map = query_loader.load_query("queries/table_tests_map.scm")

M.table_tests_inline_field_access =
  query_loader.load_query("queries/table_tests_inline_field_access.scm")

--- Check if Go tree-sitter parser is available
--- @return boolean True if Go parser is available, false otherwise
function M.has_go_parser()
  if vim.treesitter.language and vim.treesitter.language.add then
    return pcall(function()
      vim.treesitter.language.add("go")
    end)
  end
  return false
end

--- Detect test names in Go *._test.go files.
--- @param file_path string Absolute path to the Go test file
--- @return neotest.Tree|nil Tree of detected tests, or nil if parsing failed
function M.detect_tests(file_path)
  if not M.has_go_parser() then
    logger.error(
      "Go tree-sitter parser not found. Install with :TSInstall go",
      true
    )
    return nil
  end

  local opts = { nested_tests = true }
  local query = M.test_function
    .. M.table_tests_list
    .. M.table_tests_loop
    .. M.table_tests_unkeyed
    .. M.table_tests_loop_unkeyed
    .. M.table_tests_map
    .. M.table_tests_inline_field_access

  if options.get().testify_enabled == true then
    -- detect receiver types (as namespaces) and test methods.
    query = query
      .. testify.query.namespace_query
      .. testify.query.test_method_query
      .. testify.query.subtest_query
      .. testify.query.table_tests_map_query
  end

  ---@type neotest.Tree
  local tree = lib.treesitter.parse_positions(file_path, query, opts)

  if options.get().testify_enabled == true then
    tree = testify.tree_modification.modify_neotest_tree(file_path, tree)
  end

  -- Check for duplicate subtests in the tree
  if options.get().warn_test_name_dupes then
    dupe.warn_duplicate_tests(tree)
  end

  return tree
end

return M
