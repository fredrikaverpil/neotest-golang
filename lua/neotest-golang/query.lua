--- Detect test names in Go *._test.go files.

local lib = require("neotest.lib")

local discovery_cache = require("neotest-golang.lib.discovery_cache")
local dupe = require("neotest-golang.lib.dupe")
local logger = require("neotest-golang.lib.logging")
local options = require("neotest-golang.options")
local query_loader = require("neotest-golang.lib.query_loader")
local tabletest = require("neotest-golang.lib.tabletest")
local testify = require("neotest-golang.features.testify")

local M = {}

M.test_function = query_loader.load_query("queries/go/test_function.scm")

-- Table-test cases are detected with element-scoped queries: each struct
-- element is matched on its own, without also matching the surrounding
-- `for ... t.Run(...)` loop. This avoids tree-sitter dropping the leading
-- matches of large tables (issue #581); the loop validation is instead done in
-- Lua, in M._build_position. See lib/tabletest.lua for details.
M.table_tests_keyed =
  query_loader.load_query("queries/go/table_tests_keyed.scm")

M.table_tests_unkeyed =
  query_loader.load_query("queries/go/table_tests_unkeyed.scm")

M.table_tests_map = query_loader.load_query("queries/go/table_tests_map.scm")

--- Build a neotest position from a query match's captured nodes.
---
--- This mirrors neotest's default `build_position`, and additionally validates
--- table-test cases: the element-scoped table_tests_*.scm queries match every
--- struct element that *could* be a test case, and this function keeps only the
--- ones that are actually run as subtests by a surrounding `for ... t.Run(...)`
--- loop (see lib/tabletest.lua). Elements that are not run are discarded by
--- returning nil.
---
--- Passed to neotest by name (see M.detect_tests), so it must be reachable via
--- `require('neotest-golang.query')._build_position` and self-contained.
---
--- @param file_path string
--- @param source string
--- @param captured_nodes table<string, TSNode>
--- @return neotest.Position|nil
function M._build_position(file_path, source, captured_nodes)
  local match_type
  if captured_nodes["test.name"] then
    match_type = "test"
  elseif captured_nodes["namespace.name"] then
    match_type = "namespace"
  end
  if not match_type then
    return nil
  end

  local definition = captured_nodes[match_type .. ".definition"]

  -- Validate table-test cases against the surrounding loop. The marker captures
  -- are only present on matches from the element-scoped table_tests_*.scm
  -- queries; regular tests and subtests fall through unchanged.
  local field_node = captured_nodes["test.tabletest.field"]
  if field_node then
    local field = vim.treesitter.get_node_text(field_node, source)
    if not tabletest.is_slice_case_run(source, definition, field) then
      return nil
    end
  elseif captured_nodes["test.tabletest.mapkey"] then
    if not tabletest.is_map_case_run(source, definition) then
      return nil
    end
  end

  return {
    type = match_type,
    path = file_path,
    name = vim.treesitter.get_node_text(
      captured_nodes[match_type .. ".name"],
      source
    ),
    range = { definition:range() },
  }
end

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
--- Uses caching to avoid redundant parsing when the file hasn't changed.
--- This prevents performance issues when DAP-UI or other plugins trigger
--- multiple buffer events rapidly.
--- @param file_path string Absolute path to the Go test file
--- @return neotest.Tree|nil Tree of detected tests, or nil if parsing failed
function M.detect_tests(file_path)
  local cached = discovery_cache.get(file_path)
  if cached then
    return cached
  end

  if not M.has_go_parser() then
    logger.error(
      "Go tree-sitter parser not found. Install with :TSInstall go",
      true
    )
    return nil
  end

  -- The element-scoped table-test queries match struct elements that may or may
  -- not be run as subtests; `_build_position` validates each one against the
  -- surrounding `for ... t.Run(...)` loop and discards the rest. It is passed as
  -- a string so neotest can keep parsing in a subprocess (function values would
  -- force in-process parsing); see lib/treesitter in neotest.
  local opts = {
    nested_tests = true,
    build_position = "require('neotest-golang.query')._build_position",
  }
  local query = M.test_function
    .. M.table_tests_keyed
    .. M.table_tests_unkeyed
    .. M.table_tests_map

  if options.get().testify_enabled == true then
    -- Testify queries are ADDITIVE - they work on top of regular queries.
    -- This allows detection of both regular Go tests and testify suites in the same file.
    --
    -- Adds detection for:
    -- - Receiver types: func (s *Suite) TestXxx()
    -- - Table tests inside those methods
    --
    -- Note: Subtest detection for both t.Run() and suite.Run() is already
    -- combined in test_function.scm to avoid query conflicts.
    query = query
      .. testify.query.testify_method_query
      .. testify.query.table_tests_map_query
      .. testify.query.table_tests_list_query
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

  discovery_cache.set(file_path, tree)
  return tree
end

return M
