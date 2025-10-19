# Testify Support: Flat Structure Implementation

This document explains the current flat structure approach for testify suite support, how it evolved from previous implementations, and why it's the chosen solution.

## Table of Contents

- [Evolution of Testify Support](#evolution-of-testify-support)
- [The Flat Structure Approach](#the-flat-structure-approach)
- [Key Benefits](#key-benefits)
- [How It Works](#how-it-works)
- [Migration from Namespace Approach](#migration-from-namespace-approach)
- [Issue #482: Package Collision Fix](#issue-482-package-collision-fix)
- [Technical Implementation](#technical-implementation)
- [Trade-offs](#trade-offs)

---

## Evolution of Testify Support

Testify suite support in neotest-golang has undergone several iterations:

1. **Namespace Hierarchy (original)** - Created namespace nodes containing test methods
2. **Gap Logic** ([GAP.md](GAP.md)) - Added gap detection to fix "nearest test" issues
3. **Method Ownership Map** ([METHOD_OWNERSHIP_MAP.md](METHOD_OWNERSHIP_MAP.md)) - Attempted to improve nearest test with method ownership
4. **Flat Structure (current)** - This document describes the current implementation

Each iteration attempted to solve the fundamental challenge: how to represent testify receiver methods in Neotest's tree structure while maintaining usability.

---

## The Flat Structure Approach

The flat structure eliminates namespace nodes entirely and represents testify tests as flat test entries with prefixed IDs:

**Tree Structure:**
```
- file_test.go
  ├── TestSuite/TestMethod1
  ├── TestSuite/TestMethod2
  └── RegularTest
```

**Position IDs:**
```
/path/file_test.go::TestSuite/TestMethod1
/path/file_test.go::TestSuite/TestMethod2
/path/file_test.go::RegularTest
```

**Generated Go Test Command:**
```bash
go test -run ^TestSuite/TestMethod1$
```

This matches Go's native test execution format, making the adapter's behavior predictable and aligned with standard Go testing.

---

## Key Benefits

### 1. Simpler "Nearest Test" Behavior

With flat structure, "nearest test" works correctly because:
- Tests appear in the order they're defined in the file
- No complex namespace traversal required
- Neotest's default "nearest" algorithm handles it naturally

### 2. Matches `go test -run` Syntax

The test IDs directly map to Go's `-run` flag format:
- Testify: `TestSuite/TestMethod` → `-run ^TestSuite/TestMethod$`
- Regular: `TestName` → `-run ^TestName$`
- Subtests: `TestName/Subtest` → `-run ^TestName/Subtest$`

### 3. Reduced Complexity

Compared to previous approaches:
- **No gap logic** - Don't need to calculate gaps between methods
- **No synthetic nodes** - No cross-file method support needed
- **No namespace mutations** - No complex tree modifications
- **~63 lines net reduction** in code

### 4. Better User Experience

- Suite runner functions are hidden (less clutter)
- Test names are clearer: `TestSuite/TestMethod` vs nested `TestSuite > TestMethod`
- Consistent with how users think about running testify tests

---

## How It Works

### 1. Query Phase

Discover tests using tree-sitter queries:
```lua
-- Regular tests (including suite runner functions)
func Test*

-- Testify receiver methods
func (receiver *ReceiverType) Test*
```

### 2. Lookup Generation

Build a package-qualified lookup mapping:
```lua
{
  ["package.ReceiverType"] = {
    suite_function = "TestMySuite",
    methods = {
      { name = "TestMethod1", ... },
      { name = "TestMethod2", ... }
    }
  }
}
```

### 3. Tree Modification

Transform the Neotest tree:
```lua
-- Remove suite runner functions from tree
if is_suite_function(node) then
  remove_node(node)
end

-- Rename testify methods with suite prefix
if is_testify_method(node) then
  node.id = path .. "::" .. suite_name .. "/" .. method_name
  node.name = suite_name .. "/" .. method_name
end
```

### 4. Test Execution

The conversion function handles ID transformation:
```lua
pos_id_to_go_test_name("/path/file.go::TestSuite/TestMethod")
-- Returns: "TestSuite/TestMethod"

to_gotest_regex_pattern("TestSuite/TestMethod")
-- Returns: "^TestSuite/TestMethod$"
```

No special handling needed - the `/` separator is preserved throughout.

---

## Migration from Namespace Approach

### Old Tree Structure (Namespace)
```
- file_test.go
  └── TestSuite (namespace)
      ├── TestMethod1 (test)
      └── TestMethod2 (test)
```

### New Tree Structure (Flat)
```
- file_test.go
  ├── TestSuite/TestMethod1 (test)
  └── TestSuite/TestMethod2 (test)
```

### Breaking Changes

- **Position IDs changed**: `::TestSuite::TestMethod` → `::TestSuite/TestMethod`
- **No namespace nodes**: Users won't see suite functions in the tree
- **Separator changed**: From `::` to `/` between suite and method names

### Benefits of Migration

- Eliminates "nearest test" issues without gap logic
- Simpler mental model for users
- Better alignment with Go test execution
- Reduced maintenance burden

---

## Issue #482: Package Collision Fix

The flat structure implementation also fixed [issue #482](https://github.com/fredrikaverpil/neotest-golang/issues/482) where test methods would leak between packages with same-named suite structs.

### Problem

Two packages with identically named suite structs:
```go
// package foo_test
type TestSuite struct { suite.Suite }
func (s *TestSuite) TestFoo() { ... }

// package bar_test
type TestSuite struct { suite.Suite }
func (s *TestSuite) TestBar() { ... }
```

With simple receiver name keys, methods leaked:
```lua
lookup = {
  ["TestSuite"] = {  -- Collision! Both packages use same key
    methods = { "TestFoo", "TestBar" }  -- Wrong!
  }
}
```

### Solution

Use **package-qualified receiver keys**:
```lua
lookup = {
  ["foo_test.TestSuite"] = {
    methods = { "TestFoo" }
  },
  ["bar_test.TestSuite"] = {
    methods = { "TestBar" }
  }
}
```

This ensures suite methods are correctly associated with their parent suite, even across packages.

---

## Technical Implementation

### Key Files Modified

1. **`lua/neotest-golang/features/testify/lookup.lua`**
   - Changed to use package-qualified receiver keys
   - Format: `"package.ReceiverType"`

2. **`lua/neotest-golang/features/testify/tree_modification.lua`**
   - Removed namespace node creation
   - Removed gap logic (~40 lines)
   - Removed cross-file method support (~30 lines)
   - Added suite function hiding
   - Added ID renaming with `/` separator

3. **`lua/neotest-golang/lib/convert.lua`**
   - No changes needed! Already handles `/` in test names
   - `pos_id_to_go_test_name()` preserves first segment after `::`
   - Works for both `TestName` and `SuiteName/TestName`

### Test Coverage

- Unit tests in `spec/unit/convert_spec.lua` verify ID conversion
- Integration tests in `spec/integration/testifysuites_*_spec.lua`
- All existing tests pass with flat structure
- Issue #482 regression tests added

---

## Trade-offs

### Advantages ✅

- **Simpler implementation** - Less code, easier to maintain
- **Better UX** - Clearer test names, works with "nearest test"
- **Matches Go conventions** - Aligns with `go test -run` format
- **Fixes issue #482** - Package-qualified keys prevent collisions
- **No "gap logic"** - Don't need complex range calculations

### Limitations ⚠️

- **No visual suite grouping** - Can't collapse/expand suite as a group
- **Suite functions hidden** - Can't run all tests by clicking suite function
- **Breaking change** - Position IDs changed for existing users

### Migration Path

Users upgrading to the flat structure will see:
- Different test IDs in saved sessions
- No namespace entries in tree
- Tests at file level instead of nested

This is a **one-time migration** that improves usability going forward.

---

## Conclusion

The flat structure approach represents the culmination of lessons learned from previous implementations. By embracing Go's native test execution model and simplifying the tree representation, we achieve:

- **Reliability** - "Nearest test" works correctly
- **Simplicity** - Less code, fewer edge cases
- **Maintainability** - Easier to debug and extend
- **Correctness** - Fixes package collision issues (issue #482)

While we lose the visual grouping of namespace nodes, the practical benefits far outweigh this trade-off for the majority of users.

**Branches:**
- Implementation: `feat/testify-robustness`
- Previous approaches: `fix/testify-nearest` (gap), `fix/testify-nearest-v2` (method ownership)

**Related Issues:**
- [#482](https://github.com/fredrikaverpil/neotest-golang/issues/482) - Same suite struct name in different packages causes test method leaking
