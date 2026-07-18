--- Validation helpers for table-driven test discovery.
---
--- Table-test cases are discovered with *element-scoped* tree-sitter queries
--- (see queries/go/table_tests_*.scm): each struct element in the test-case
--- table is matched independently, without also matching the surrounding
--- `for ... t.Run(...)` loop.
---
--- This is deliberate. A single query that binds every struct element to the
--- trailing loop forces tree-sitter to keep one in-progress match alive per
--- element until the loop is reached at the end of the block. Once the number
--- of concurrent in-progress matches exceeds tree-sitter's match limit, the
--- oldest (leading) matches are silently dropped, so the *first* test cases in
--- large tables go undetected (see issue #581).
---
--- Element-scoped queries complete each match as soon as the element is parsed,
--- so matches never accumulate and detection no longer has an upper bound. The
--- loop validation that the combined query used to perform in tree-sitter
--- (queries/go/table_tests_slice_loop.scm, table_tests_map_loop.scm) is instead
--- performed here, in Lua, from `query._build_position`.

local query_loader = require("neotest-golang.lib.query_loader")

local M = {}

--- Compile (and cache) a loop-validation query from queries/go/.
local compiled = {}
--- @param path string Path to a .scm file, relative to lua/neotest-golang.
--- @return vim.treesitter.Query
local function get_query(path)
  if not compiled[path] then
    compiled[path] =
      vim.treesitter.query.parse("go", query_loader.load_query(path))
  end
  return compiled[path]
end

--- Return the nearest ancestor of `node` (exclusive) whose type is `wanted`.
--- @param node TSNode
--- @param wanted string
--- @return TSNode|nil
local function nearest_ancestor(node, wanted)
  local parent = node:parent()
  while parent do
    if parent:type() == wanted then
      return parent
    end
    parent = parent:parent()
  end
  return nil
end

--- Return the outermost ancestor of `node` (exclusive) whose type is `wanted`.
--- For a node inside a function this yields the function body, so one query
--- over its subtree covers every scope the table-test loop could be in.
--- @param node TSNode
--- @param wanted string
--- @return TSNode|nil
local function outermost_ancestor(node, wanted)
  local found = nil
  local parent = node:parent()
  while parent do
    if parent:type() == wanted then
      found = parent
    end
    parent = parent:parent()
  end
  return found
end

--- Resolve the "container" of a table-test struct element: the composite_literal
--- holding the slice/map of cases, plus how it is referenced from the loop.
---
--- Two shapes exist:
---   * inline:  for _, v := range []T{ {...} } { ... }   (container is inside the loop)
---   * variable: cases := []T{ {...} }; for _, v := range cases { ... }
---
--- @param def TSNode The @test.definition node (the struct element).
--- @param source string
--- @return TSNode|nil composite The composite_literal containing the element.
--- @return string|nil var The variable name the composite is assigned to, if any.
local function resolve_container(def, source)
  local composite = nearest_ancestor(def, "composite_literal")
  if not composite then
    return nil, nil
  end

  -- Named variable: `cases := []T{ ... }` (short_var_declaration) or
  -- `var cases = []T{ ... }` (var_spec). Grab the first identifier being
  -- assigned to.
  local decl = nearest_ancestor(composite, "short_var_declaration")
  if decl then
    local left = decl:field("left")[1]
    local name = left and left:named_child(0)
    if name and name:type() == "identifier" then
      return composite, vim.treesitter.get_node_text(name, source)
    end
    return composite, nil
  end
  local spec = nearest_ancestor(composite, "var_spec")
  if spec then
    local name = spec:field("name")[1]
    if name then
      return composite, vim.treesitter.get_node_text(name, source)
    end
  end

  return composite, nil
end

--- Does the loop iterate over this element's container?
--- @param range_src TSNode The @range.src node from a loop query match.
--- @param composite TSNode The element's container composite_literal.
--- @param var string|nil The variable the container is assigned to, if any.
--- @param source string
--- @return boolean
local function loop_targets_container(range_src, composite, var, source)
  -- Inline table: the loop ranges directly over the composite literal.
  if range_src:id() == composite:id() then
    return true
  end
  -- Variable table: the loop ranges over the identifier the composite is
  -- assigned to.
  if var ~= nil and range_src:type() == "identifier" then
    return vim.treesitter.get_node_text(range_src, source) == var
  end
  return false
end

--- Collect the capture-name -> node map for a single match.
local function match_captures(query, match)
  local caps = {}
  for id, nodes in pairs(match) do
    local name = query.captures[id]
    local list = type(nodes) == "table" and nodes or { nodes }
    caps[name] = list[#list]
  end
  return caps
end

--- Scan the outermost block enclosing `def` for a loop match that `accept`s.
--- @param query vim.treesitter.Query
--- @param source string
--- @param def TSNode
--- @param accept fun(caps: table<string, TSNode>): boolean
--- @return boolean
local function scan_for_loop(query, source, def, accept)
  local block = outermost_ancestor(def, "block")
  if not block then
    return false
  end
  for _, match in query:iter_matches(block, source, 0, -1, { all = true }) do
    if accept(match_captures(query, match)) then
      return true
    end
  end
  return false
end

--- Memoized validation results for the source currently being parsed. Every
--- element of the same table resolves to the same container, so one loop scan
--- serves all of its cases. Keyed by the container's position in the source;
--- reset whenever a different source is validated.
local memo_source = nil
local memo = {}
--- @param source string
--- @param key string
--- @param fn fun(): boolean
--- @return boolean
local function memoize(source, key, fn)
  if memo_source ~= source then
    memo_source = source
    memo = {}
  end
  if memo[key] == nil then
    memo[key] = fn()
  end
  return memo[key]
end

--- Validate that a *slice* table-test element is actually run as a subtest:
--- some enclosing loop iterates over the element's container and calls
--- `t.Run(v.<field>, ...)` using the captured field.
---
--- @param source string
--- @param def TSNode The @test.definition node (struct element).
--- @param field string The struct field whose value is the subtest name.
--- @return boolean
function M.is_slice_case_run(source, def, field)
  local composite, var = resolve_container(def, source)
  if not composite then
    return false
  end

  local row, col = composite:range()
  return memoize(source, ("slice:%d:%d:%s"):format(row, col, field), function()
    local query = get_query("queries/go/table_tests_slice_loop.scm")
    return scan_for_loop(query, source, def, function(caps)
      return caps["run.field"] ~= nil
        and caps["range.src"] ~= nil
        and vim.treesitter.get_node_text(caps["run.field"], source) == field
        and loop_targets_container(caps["range.src"], composite, var, source)
    end)
  end)
end

--- Validate that a *map* table-test element is actually run as a subtest: some
--- enclosing loop iterates over the element's container (the map) and calls
--- `t.Run(key, ...)` using the range key variable.
---
--- @param source string
--- @param def TSNode The @test.definition node (map value struct).
--- @return boolean
function M.is_map_case_run(source, def)
  local composite, var = resolve_container(def, source)
  if not composite then
    return false
  end

  local row, col = composite:range()
  return memoize(source, ("map:%d:%d"):format(row, col), function()
    local query = get_query("queries/go/table_tests_map_loop.scm")
    return scan_for_loop(query, source, def, function(caps)
      return caps["range.src"] ~= nil
        and loop_targets_container(caps["range.src"], composite, var, source)
    end)
  end)
end

return M
