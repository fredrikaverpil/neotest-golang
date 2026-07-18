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
--- of concurrent in-progress matches exceeds tree-sitter's match limit (256 by
--- default in Neovim), the earliest-starting matches are silently dropped, so
--- the *first* test cases in large tables go undetected (see issue #581).
---
--- Element-scoped queries complete each match as soon as the element is parsed,
--- so matches never accumulate and detection no longer has an upper bound. The
--- loop validation that the combined query used to perform in tree-sitter
--- (queries/go/table_tests_slice_loop.scm, table_tests_map_loop.scm) is instead
--- performed here, in Lua, from `query._build_position`.
---
--- Scope mirrors the old combined queries so behaviour does not change beyond
--- the match-limit fix: the loop must be the for-statement the table is
--- declared inline in, or a *later sibling* of the table's declaration in the
--- same statement list. This keeps validation tight against shadowed variables
--- and unrelated loops elsewhere in the function.

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

local function text(node, source)
  return vim.treesitter.get_node_text(node, source)
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

--- Resolve the container of a table-test element and how it binds to its loop.
---
--- Two shapes are supported (matching the previous queries):
---   * "inline":   for _, v := range []T{ {...} } { ... }
---   * "variable": cases := []T{ {...} }; for _, v := range cases { ... }
--- `var cases = []T{ ... }` is intentionally not handled, as before.
---
--- @param def TSNode The @test.definition node (the struct element).
--- @param source string
--- @return TSNode|nil composite The container composite literal.
--- @return string|nil kind "inline" or "variable".
--- @return TSNode|nil anchor The for-statement (inline) or declaration (variable).
--- @return string|nil var The table variable name (variable shape only).
local function resolve_container(def, source)
  local composite = nearest_ancestor(def, "composite_literal")
  if not composite then
    return nil
  end

  -- Named variable: the composite is a value in a `:=` declaration. Resolve the
  -- identifier at the *same position* on the left-hand side, so a
  -- multi-assignment like `f, cases := g(), []T{...}` maps to the right name.
  local decl = nearest_ancestor(composite, "short_var_declaration")
  if decl then
    local left = decl:field("left")[1]
    local right = decl:field("right")[1]
    if left and right then
      for i = 0, right:named_child_count() - 1 do
        if right:named_child(i):id() == composite:id() then
          local name = left:named_child(i)
          if name and name:type() == "identifier" then
            return composite, "variable", decl, text(name, source)
          end
          break
        end
      end
    end
    return composite
  end

  -- Inline: the composite is the range source of a for-statement.
  local parent = composite:parent()
  if parent and parent:type() == "range_clause" then
    local for_stmt = parent:parent()
    if for_stmt and for_stmt:type() == "for_statement" then
      return composite, "inline", for_stmt, nil
    end
  end

  return composite
end

--- Does `for_stmt` iterate over `composite`? For an inline table the loop ranges
--- directly over the composite; for a variable table it ranges over `var`.
local function loop_targets_container(range_src, composite, var, source)
  if range_src:id() == composite:id() then
    return true
  end
  if var ~= nil and range_src:type() == "identifier" then
    return text(range_src, source) == var
  end
  return false
end

--- The later-sibling for-statements of `decl` in its statement list. Restricting
--- to later siblings mirrors the old combined queries (declaration and loop
--- shared a statement list, loop after declaration) and avoids matching loops
--- in nested/shadowing scopes elsewhere in the function.
--- @return TSNode[]
local function sibling_loops(decl)
  local list = decl:parent()
  local loops = {}
  if not list then
    return loops
  end
  local decl_row = decl:range()
  for child in list:iter_children() do
    if child:type() == "for_statement" then
      local child_row = child:range()
      if child_row > decl_row then
        loops[#loops + 1] = child
      end
    end
  end
  return loops
end

--- Run `accept` against each match of `query` rooted at `for_stmt`, restricted
--- to the match whose @loop is `for_stmt` itself (iter_matches also reports
--- nested loops). Returns the first truthy result.
--- @return boolean
local function loop_matches(query_path, for_stmt, source, accept)
  local query = get_query(query_path)
  for _, match in query:iter_matches(for_stmt, source, 0, -1, { all = true }) do
    local caps = match_captures(query, match)
    if caps["loop"] and caps["loop"]:id() == for_stmt:id() and accept(caps) then
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

--- Does the loop belonging to this container run a slice case via `t.Run(v.field)`?
local function slice_loop_runs(for_stmt, source, field, composite, var)
  return loop_matches(
    "queries/go/table_tests_slice_loop.scm",
    for_stmt,
    source,
    function(caps)
      return caps["run.field"] ~= nil
        and caps["range.src"] ~= nil
        and text(caps["run.field"], source) == field
        and loop_targets_container(caps["range.src"], composite, var, source)
    end
  )
end

--- Does the loop belonging to this container run a map case via `t.Run(key)`?
local function map_loop_runs(for_stmt, source, composite, var)
  return loop_matches(
    "queries/go/table_tests_map_loop.scm",
    for_stmt,
    source,
    function(caps)
      return caps["range.src"] ~= nil
        and loop_targets_container(caps["range.src"], composite, var, source)
    end
  )
end

--- Validate that a *slice* table-test element is actually run as a subtest by
--- the loop it belongs to, using the captured field as the subtest name.
--- @param source string
--- @param def TSNode The @test.definition node (struct element).
--- @param field string The struct field whose value is the subtest name.
--- @return boolean
function M.is_slice_case_run(source, def, field)
  local composite, kind, anchor, var = resolve_container(def, source)
  if not composite or not kind then
    return false
  end

  local row, col = composite:range()
  return memoize(source, ("slice:%d:%d:%s"):format(row, col, field), function()
    if kind == "inline" then
      return slice_loop_runs(anchor, source, field, composite, var)
    end
    for _, for_stmt in ipairs(sibling_loops(anchor)) do
      if slice_loop_runs(for_stmt, source, field, composite, var) then
        return true
      end
    end
    return false
  end)
end

--- Validate that a *map* table-test element is actually run as a subtest by the
--- loop it belongs to, keyed by the range key variable.
--- @param source string
--- @param def TSNode The @test.definition node (map value struct).
--- @return boolean
function M.is_map_case_run(source, def)
  -- Maps are only supported in the named-variable shape, as before.
  local composite, kind, anchor, var = resolve_container(def, source)
  if kind ~= "variable" then
    return false
  end

  local row, col = composite:range()
  return memoize(source, ("map:%d:%d"):format(row, col), function()
    for _, for_stmt in ipairs(sibling_loops(anchor)) do
      if map_loop_runs(for_stmt, source, composite, var) then
        return true
      end
    end
    return false
  end)
end

return M
