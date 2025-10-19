# Understanding the "Gap Logic" in Testify Suite Support

This document explains the gap logic feature in `tree_modification.lua`, how it was developed, and what problem it actually solves.

## Table of Contents

- [The Original Problem](#the-original-problem)
- [Investigation Journey](#investigation-journey)
- [The Core Issue: Namespace Ranges](#the-core-issue-namespace-ranges)
- [What the Lookup Provides](#what-the-lookup-provides)
- [What the Gap Logic Provides](#what-the-gap-logic-provides)
- [The Crucial Discovery](#the-crucial-discovery)
- [Trade-offs](#trade-offs)
- [Technical Details](#technical-details)
- [Recommendations](#recommendations)

---

## The Original Problem

When using Neotest's "run nearest test" feature with testify suites, the **wrong test** would execute:

**Symptom:**
- Cursor on `TestMethod2` at line 18
- Run "nearest test"
- **Entire file runs** instead of just `TestMethod2`

**Example Code:**
```go
type RegressionSuite struct { suite.Suite }

func (s *RegressionSuite) Test_MyTest1() {  // line 13
    i := 5
    s.Equal(5, i)
}

func (s *RegressionSuite) Test_MyTest2() {  // line 18
    i := 5
    s.Equal(5, i)
}

func Test_MySuite(t *testing.T) {           // line 23
    suite.Run(t, new(RegressionSuite))
}
```

This problem occurred **very frequently** - nearly every time users tried to run a specific testify suite method.

---

## Investigation Journey

### Initial Hypothesis (Incorrect)

**First assumption:** The problem was about Neotest's `nearest` algorithm traversing too many nodes (performance issue).

**Explanation attempted:** "The algorithm performs depth-first traversal and gets stuck in large namespaces with many children."

**This was WRONG.** The algorithm is fast; traversal performance wasn't the issue.

### Second Hypothesis (Partially Correct)

**Assumption:** Namespace ranges must include their methods to prevent misclassification of regular tests.

**Explanation:** "If namespace spans entire file, regular tests might be incorrectly placed under it."

**This was PARTIALLY WRONG.** The lookup table already handles classification correctly - it knows which tests are suite methods vs regular tests.

### The Breakthrough

**Actual root cause discovered:** Namespace range didn't include the method lines, so Neotest's `nearest` algorithm never entered the namespace to check its children.

**Key insight from testing with regression_test.go:**
> "When placing cursor at Test_MyTest2 line 18, the entire file runs instead of the specific test."

---

## The Core Issue: Namespace Ranges

### How Neotest's `nearest` Algorithm Works

From `.tests/all/site/pack/deps/start/neotest/lua/neotest/lib/positions/init.lua`:

```lua
function neotest.lib.positions.nearest(tree, line)
  local nearest = tree
  for _, node in tree:iter_nodes() do
    local pos = node:data()
    if pos.range then
      if line >= pos.range[1] then  -- ← THE KEY CHECK!
        nearest = node
      else
        return nearest
      end
    end
  end
  return nearest
end
```

**Critical behavior:**
1. Iterates nodes in depth-first pre-order (parent, then children)
2. Checks if `cursor_line >= node.start_line`
3. Updates "nearest" when condition is true
4. **Returns immediately** when it finds a node that starts AFTER cursor

### The Problem Without Range Adjustment

**Without adjustment:**
```
File (0-26)
└─ TestMySuite (namespace, range 23-25)  ← Only spans suite function!
   ├─ Test_MyTest1 (13-16)
   └─ Test_MyTest2 (18-21)
```

**When cursor at line 18:**
1. File (0): `18 >= 0`? ✓ → nearest = File
2. TestMySuite (23): `18 >= 23`? ✗ → **Returns File immediately!**
3. **Never checks children** because 18 < 23

**Result:** Runs entire file instead of Test_MyTest2

### The Fix: Adjust Namespace Range

**With adjustment:**
```
File (0-26)
└─ TestMySuite (namespace, range 13-25)  ← Includes all methods!
   ├─ Test_MyTest1 (13-16)
   └─ Test_MyTest2 (18-21)
```

**When cursor at line 18:**
1. File (0): `18 >= 0`? ✓ → nearest = File
2. TestMySuite (13): `18 >= 13`? ✓ → nearest = TestMySuite
3. **Enters namespace**, checks children:
   - Test_MyTest1 (13): `18 >= 13`? ✓ → nearest = Test_MyTest1
   - Test_MyTest2 (18): `18 >= 18`? ✓ → nearest = Test_MyTest2 ✓

**Result:** Runs Test_MyTest2 correctly!

---

## What the Lookup Provides

The lookup table (generated in `lookup.lua`) provides:

```lua
---@class TestifyFileData
---@field replacements table<string, string>  -- Receiver type → Suite function name
---@field methods table<string, TestifyMethodInstance[]>  -- Method name → Instances
```

**What it solves:**
- ✅ **Classification:** Knows which methods belong to which suite (via receiver types)
- ✅ **Cross-file support:** Tracks methods defined in different files than their suite function
- ✅ **Tree structure:** Tells us which tests should be children of which namespaces

**What it doesn't solve:**
- ❌ **Namespace ranges:** Doesn't automatically adjust namespace line ranges
- ❌ **"Nearest test" correctness:** Range adjustment must still happen separately

---

## What the Gap Logic Provides

The gap logic (MAX_GAP = 20 lines) in `separate_contiguous_children()` does two things:

### 1. Determines Which Methods Are "Contiguous"

```lua
local MAX_GAP = 20
-- Methods separated by ≤20 lines: CONTIGUOUS → Stay as namespace children
-- Methods separated by >20 lines: NON-CONTIGUOUS → Move to root level
```

**Example:**
```go
func (s *Suite) TestMethod1() { ... }  // line 13-16
func (s *Suite) TestMethod2() { ... }  // line 18-21
// Gap = 18 - 16 = 2 lines: CONTIGUOUS ✓

func (s *Suite) TestMethod3() { ... }  // line 200-203
// Gap = 200 - 21 = 179 lines: NON-CONTIGUOUS ✗
```

### 2. Adjusts Namespace Range Based on Contiguous Methods

```lua
-- With gap logic:
namespace_pos.range[1] = first_contiguous_method.range[1]  -- line 13
namespace_pos.range[3] = max(last_contiguous_method.range[3], suite_function.range[3])  -- line 25

-- Result: Namespace range = [13, 25]
-- TestMethod3 moved to root level with ID: path::TestMySuite::TestMethod3
```

**Tree structure with gap logic:**
```
File
├─ TestMySuite (namespace, 13-25)  ← Accurate range for related methods
│  ├─ TestMethod1 (13-16)
│  └─ TestMethod2 (18-21)
└─ TestMethod3 (200-203, ID: path::TestMySuite::TestMethod3)  ← Root level but still executable!
```

---

## The Crucial Discovery

### Gap Logic Is NOT Required for Correctness!

The **minimum fix** that solves "run nearest test" is simply:

```lua
-- Adjust namespace range to include ALL methods (no gap threshold)
namespace_pos.range[1] = first_method.range[1]
namespace_pos.range[3] = max(last_method.range[3], suite_function.range[3])
```

**Without gap logic (but with range adjustment):**
```
File
└─ TestMySuite (namespace, 13-500)  ← Spans all methods
   ├─ TestMethod1 (13-16)
   ├─ TestMethod2 (18-21)
   └─ TestMethod3 (200-203)
```

**When cursor at line 200:**
1. TestMySuite (13): `200 >= 13`? ✓ → Enters namespace
2. Finds TestMethod3 at line 200 ✓

**This works perfectly!**

### What Gap Logic Actually Provides

Gap logic is a **design choice** for:
- ✅ **Aesthetics:** Avoids namespace spanning hundreds of lines
- ✅ **Intuition:** Methods 200 lines apart probably aren't conceptually related
- ✅ **Tree structure preference:** Flatter tree vs deeper nested tree

But it's **NOT** required for:
- ❌ **Correctness:** "Run nearest test" works with or without it
- ❌ **Performance:** Traversal is fast either way
- ❌ **Classification:** Lookup handles that

---

## Trade-offs

### With Gap Logic (Current Implementation)

**Pros:**
- Tree structure matches developer intuition (related methods grouped)
- Namespace ranges are accurate (don't span unrelated code)
- Clear separation between "clusters" of methods

**Cons:**
- More complex code (~80 lines for `separate_contiguous_children`)
- Arbitrary threshold (why 20 lines? why not 10 or 50?)
- Harder to explain to users
- Non-contiguous methods at root level might be surprising

### Without Gap Logic (Simpler Alternative)

**Pros:**
- Much simpler code (~10 lines to adjust range)
- No arbitrary thresholds
- Easier to understand: "All suite methods are children of their namespace"
- Less surprising behavior

**Cons:**
- Namespace might span hundreds of lines if methods are scattered
- Tree structure less intuitive for files with widely-separated methods
- Mixing related and unrelated code under one namespace node

---

## Technical Details

### The Core Fix (Lines 485-498 in tree_modification.lua)

```lua
-- Adjust namespace range based on contiguous children
if #contiguous > 0 then
  local first_range = contiguous[1]:data().range
  local last_range = contiguous[#contiguous]:data().range

  if first_range and last_range then
    if namespace_pos.range then
      namespace_pos.range[1] = first_range[1]  -- ← KEY: Set start to first method!
      namespace_pos.range[3] = math.max(last_range[3], namespace_pos.range[3])
    else
      namespace_pos.range = { first_range[1], 0, last_range[3], 0 }
    end
  end
end
```

**This is what fixes "run nearest test"!**

### The Gap Threshold Calculation (Lines 452-477)

```lua
local MAX_GAP = 20

local prev_end = nil
for _, child_tree in ipairs(children) do
  local child_pos = child_tree:data()
  if child_pos.range then
    if prev_end == nil then
      table.insert(contiguous, child_tree)
      prev_end = child_pos.range[3]
    else
      local gap = child_pos.range[1] - prev_end  -- Distance between methods
      if gap <= MAX_GAP then
        table.insert(contiguous, child_tree)
        prev_end = child_pos.range[3]
      else
        table.insert(non_contiguous, child_tree)  -- Move to root
      end
    end
  end
end
```

**This determines tree structure preference, not correctness.**

---

## Recommendations

### For Understanding

When explaining this feature:
1. **Start with the core problem:** Namespace range must include methods
2. **Explain the algorithm:** How `nearest` checks `line >= range[1]`
3. **Show the fix:** Range adjustment from suite function line to first method line
4. **Then explain gap logic:** Optional tree structuring based on proximity

### For Future Development

**Option 1: Keep gap logic**
- Document it as a tree structure preference, not a correctness requirement
- Make MAX_GAP configurable via options
- Add tests showing it works with and without gap logic

**Option 2: Remove gap logic**
- Simplify to just range adjustment
- Document that namespaces might span large line ranges
- Trade simplicity for aesthetics

**Option 3: Make it optional**
- Add option: `testify.group_non_contiguous_methods = true/false`
- Default to false (simpler behavior)
- Let users opt-in to gap logic if they prefer

### For Documentation

The current documentation should emphasize:
1. ✅ **The real problem:** Namespace range not including methods
2. ✅ **The core fix:** Range adjustment to span methods
3. ⚠️ **Gap logic:** Optional tree structuring feature (not correctness)

Avoid saying:
- ❌ "Prevents algorithm from getting stuck"
- ❌ "Performance optimization"
- ❌ "Required for nearest test to work"

---

## Summary

**What we thought:** Gap logic is needed to prevent traversal problems
**What's actually true:** Gap logic is a tree structure preference

**The real fix:** Adjust namespace range from `[suite_function_line]` to `[first_method_line, ..., suite_function_line]`

**The gap threshold (20 lines):** Determines whether methods are grouped together or separated, but doesn't affect correctness

**The lookup:** Handles classification (which methods belong to which suite)
**The range adjustment:** Makes "run nearest test" work correctly
**The gap logic:** Makes the tree prettier/more intuitive

---

## References

- Neotest's `nearest` algorithm: `.tests/all/site/pack/deps/start/neotest/lua/neotest/lib/positions/init.lua` (lines 17-30)
- Gap logic implementation: `lua/neotest-golang/features/testify/tree_modification.lua` (lines 420-498)
- Lookup table generation: `lua/neotest-golang/features/testify/lookup.lua`
- Original issue: Cursor on method line → entire file runs instead of specific method
- Test case: `tests/features/internal/testifysuites/regression_test.go`
