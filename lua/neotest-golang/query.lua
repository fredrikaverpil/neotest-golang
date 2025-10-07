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
  -- Multiple fallback checks for Go parser availability

  -- Method 1: Try vim.treesitter.language.add (newer API)
  if vim.treesitter.language and vim.treesitter.language.add then
    local success = pcall(function()
      vim.treesitter.language.add("go")
    end)
    if success then
      return true
    end
  end

  -- Method 2: Try creating a parser directly
  local parse_success = pcall(function()
    local parser = vim.treesitter.get_parser(0, "go")
    return parser ~= nil
  end)
  if parse_success then
    return true
  end

  -- Method 3: Check if nvim-treesitter has the parser registered
  local ts_parsers_success, ts_parsers =
    pcall(require, "nvim-treesitter.parsers")
  if ts_parsers_success and ts_parsers then
    local info_success, info = pcall(ts_parsers.get_parser_info, "go")
    if info_success and info then
      return true
    end
  end

  -- Method 4: Check for parser file existence
  local parser_paths = {
    ".tests/all/site/parser/go.so",
    vim.fn.stdpath("data") .. "/lazy/nvim-treesitter/parser/go.so",
    vim.fn.stdpath("data")
      .. "/site/pack/packer/start/nvim-treesitter/parser/go.so",
  }

  for _, parser_path in ipairs(parser_paths) do
    if vim.fn.filereadable(parser_path) == 1 then
      return true
    end
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
    -- Testify queries are ADDITIVE - they work on top of regular queries.
    -- This allows detection of both regular Go tests and testify suites in the same file.
    --
    -- Adds detection for:
    -- - Receiver types (as namespaces): func (s *Suite) TestXxx()
    -- - Test methods on those receivers
    --
    -- Note: Subtest detection for both t.Run() and suite.Run() is already
    -- combined in test_function.scm to avoid query conflicts.
    query = query
      .. testify.query.namespace_query
      .. testify.query.test_method_query
  end

  ---@type neotest.Tree
  local tree
  local parse_success, parse_result = pcall(function()
    return lib.treesitter.parse_positions(file_path, query, opts)
  end)

  if not parse_success then
    logger.error(
      "Failed to parse Go test file: " .. tostring(parse_result),
      true
    )
    -- Return a minimal empty tree to prevent crashes
    return lib.treesitter.parse_positions_from_string(
      file_path,
      "",
      query,
      opts
    )
  end

  tree = parse_result

  if options.get().testify_enabled == true then
    local testify_success, testify_result = pcall(function()
      return testify.tree_modification.modify_neotest_tree(file_path, tree)
    end)
    if testify_success then
      tree = testify_result
    else
      logger.warn(
        "Failed to apply testify modifications: " .. tostring(testify_result)
      )
    end
  end

  -- Check for duplicate subtests in the tree
  if options.get().warn_test_name_dupes then
    pcall(dupe.warn_duplicate_tests, tree)
  end

  return tree
end

return M
