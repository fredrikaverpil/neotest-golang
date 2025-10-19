# Solution: Smart Conflict Detection for Testify Suite Support

This document explains the final solution for fixing "run nearest test" with testify suites.

## Table of Contents

- [The Problem](#the-problem)
- [The Journey](#the-journey)
- [The Solution](#the-solution)
- [Implementation Details](#implementation-details)
- [Why This Works](#why-this-works)
- [Trade-offs](#trade-offs)

---

## The Problem

### Original Issue

When using Neotest's "run nearest test" with testify suites, the **wrong test** would execute:

**Symptom:**
- Cursor placed at line 54 where `ExampleTestSuite2.TestExample` is defined
- Run "nearest test"
- **Different test runs**: `ExampleTestSuite/TestExample2` (wrong suite!)

### Root Cause Analysis

**The file structure** (`positions_test.go`):
```go
func (suite *ExampleTestSuite) TestExample() {}      // line 27
func (suite *ExampleTestSuite) TestExample2() {}     // line 31
func TestExampleTestSuite(t *testing.T) {}           // line 37

func (suite *ExampleTestSuite2) TestExample() {}     // line 54 ← User cursor here
func (suite *ExampleTestSuite2) TestExample2() {}    // line 58

func (suite *ExampleTestSuite) TestSubTestOperand1() {}  // line 83
func (s *ExampleTestSuite) TestSubTestOperand2() {}      // line 91
```

**Without proper namespace range handling:**
```
File
└─ TestExampleTestSuite (namespace, range [27, 96])  ← Spans ALL ExampleTestSuite methods
   ├─ TestExample (27-29)
   ├─ TestExample2 (31-33)
   ├─ TestSubTestOperand1 (83-88)
   └─ TestSubTestOperand2 (91-96)
└─ TestExampleTestSuite2 (namespace, [54, 64])
   ├─ TestExample (54-56)
   └─ TestExample2 (58-60)
```

**When cursor at line 54:**
1. Neotest's `nearest` algorithm: `54 >= 27`? YES → Enters `TestExampleTestSuite` namespace
2. Checks children: TestExample (27), TestExample2 (31) both match
3. Stops at TestSubTestOperand1 (54 < 83)
4. Returns `TestExampleTestSuite/TestExample2` ✗

**The algorithm never reaches `TestExampleTestSuite2`** because it already entered the first namespace and found a match.

### Why This Happens

**Neotest's `nearest` algorithm** (from `.tests/all/site/pack/deps/start/neotest/lua/neotest/lib/positions/init.lua`):

```lua
function nearest(tree, line)
  local nearest = tree
  for _, node in tree:iter_nodes() do  -- Depth-first traversal
    if node.range and line >= node.range[1] then
      nearest = node
    else
      return nearest  -- Stops at first node after cursor!
    end
  end
end
```

**Key behavior:** Once it enters a namespace (because `cursor_line >= namespace.range[1]`), it only checks that namespace's children. If it finds a match, it stops and returns - **never checking sibling namespaces**.

**The problem:** Namespace ranges that span too many lines cause the algorithm to enter the wrong namespace.

---

## The Journey

### Attempt 1: Remove Gap Logic (Failed)

**Approach:** Simplify by removing all gap logic, let namespace span all methods.

**Result:** Made the problem worse! Namespace ranges became even larger, causing more overlap.

**Why it failed:** Without any separation mechanism, `TestExampleTestSuite` namespace spanned lines 27-96, which includes line 54 where `ExampleTestSuite2` methods are defined.

### Attempt 2: Restore Gap Logic with MAX_GAP = 20 (Works but Arbitrary)

**Approach:** Use the original gap logic - separate methods >20 lines apart.

**Result:** Works! But uses arbitrary threshold.

**Tree structure with gap logic:**
```
File
├─ TestExampleTestSuite (namespace, [27, 37])  ← Only close methods
│  ├─ TestExample (27-29)
│  └─ TestExample2 (31-33)
├─ TestExampleTestSuite2 (namespace, [54, 64])
│  ├─ TestExample (54-56)
│  └─ TestExample2 (58-60)
├─ TestSubTestOperand1 (83-88)  ← Root level (>20 lines from TestExample2)
└─ TestSubTestOperand2 (91-96)
```

**Why it works:** Gap of 23 lines (54 - 31) causes TestSubTestOperand1 to split off, so namespace only spans [27, 37], which doesn't include line 54.

**Issues:**
- ❌ Arbitrary threshold: Why 20 lines? Why not 10 or 50?
- ❌ Hard to explain to users
- ❌ Methods 21 lines apart always separate (even without conflict)
- ❌ Doesn't use lookup table data intelligently

### Attempt 3: Smart Conflict Detection (Final Solution)

**Approach:** Use lookup table to detect when another suite's methods are "in the way".

**Key insight:** We don't need arbitrary thresholds. We can detect **actual conflicts** by checking if another suite owns methods between our suite's methods.

---

## The Solution

### Core Algorithm

**1. Build Method Ownership Map** (from lookup table):
```lua
-- Maps line numbers to suite names
method_ownership_map = {
  [27] = "TestExampleTestSuite",
  [28] = "TestExampleTestSuite",
  [29] = "TestExampleTestSuite",
  [31] = "TestExampleTestSuite",
  [32] = "TestExampleTestSuite",
  [33] = "TestExampleTestSuite",
  [54] = "TestExampleTestSuite2",  -- ← Conflict marker!
  [55] = "TestExampleTestSuite2",
  [56] = "TestExampleTestSuite2",
  -- ... etc
}
```

**2. Detect Conflicts When Processing Children:**

For each suite's methods (sorted by line):
- Start with first method → always contiguous
- For each subsequent method:
  - Check lines between last contiguous method and current method
  - If **any line is owned by a different suite** → CONFLICT!
  - Conflict → move current method to root level
  - No conflict → add to contiguous group

**3. Adjust Namespace Range:**
- Namespace range = [first_contiguous_method, max(last_contiguous_method, suite_function)]
- Only spans contiguous (non-conflicting) methods

### Example Walkthrough

**Processing `TestExampleTestSuite` methods:**

```
Methods: [TestExample (27-29), TestExample2 (31-33), TestSubTestOperand1 (83-88), TestSubTestOperand2 (91-96)]

Step 1: TestExample (27-29)
- First method → contiguous

Step 2: TestExample2 (31-33)
- Check lines 30-30 (between 29 and 31)
- No owner → contiguous

Step 3: TestSubTestOperand1 (83-88)
- Check lines 34-82 (between 33 and 83)
- Line 54 owned by "TestExampleTestSuite2" ← CONFLICT!
- Move to root level

Step 4: TestSubTestOperand2 (91-96)
- Previous was non-contiguous → also non-contiguous

Result:
- Contiguous: [TestExample, TestExample2]
- Namespace range: [27, 37]
- Non-contiguous (root level): [TestSubTestOperand1, TestSubTestOperand2]
```

**Processing `TestExampleTestSuite2` methods:**

```
Methods: [TestExample (54-56), TestExample2 (58-60)]

Step 1: TestExample (54-56)
- First method → contiguous

Step 2: TestExample2 (58-60)
- Check lines 57-57 (between 56 and 58)
- No owner → contiguous

Result:
- Contiguous: [TestExample, TestExample2]
- Namespace range: [54, 64]
- Non-contiguous: []
```

**Final tree structure:**
```
File
├─ TestExampleTestSuite (namespace, [27, 37])
│  ├─ TestExample (27-29)
│  └─ TestExample2 (31-33)
├─ TestExampleTestSuite2 (namespace, [54, 64])
│  ├─ TestExample (54-56)
│  └─ TestExample2 (58-60)
├─ TestSubTestOperand1 (83-88, ID: path::TestExampleTestSuite::TestSubTestOperand1)
└─ TestSubTestOperand2 (91-96, ID: path::TestExampleTestSuite::TestSubTestOperand2)
```

**Cursor at line 54:**
1. `54 >= 27`? YES → Enters `TestExampleTestSuite` namespace
2. TestExample (27): `54 >= 27` ✓
3. TestExample2 (31): `54 >= 31` ✓
4. **End of namespace children** (only 2 children!)
5. Exits namespace, continues to next sibling
6. `54 >= 54`? YES → Enters `TestExampleTestSuite2` namespace
7. TestExample (54): `54 >= 54` ✓
8. **Returns `TestExampleTestSuite2/TestExample`** ✓

---

## Implementation Details

### File Modified

`lua/neotest-golang/features/testify/tree_modification.lua`

### Key Functions

**1. Build ownership map** (lines 400-427):
```lua
local method_ownership_map = {}

-- Populate from lookup table
for method_name, instances in pairs(file_data.methods) do
  for _, instance in ipairs(instances) do
    local node = instance.definition.node
    local start_row, _, end_row, _ = node:range()
    local suite_name = replacements[instance.receiver]

    for line = start_row, end_row do
      method_ownership_map[line] = suite_name
    end
  end
end
```

**2. Conflict detection** (lines 429-509):
```lua
local function separate_by_conflicts(children, current_suite_name, namespace_pos)
  local contiguous = {}
  local conflicting = {}

  for _, child_tree in ipairs(children) do
    if #contiguous == 0 then
      table.insert(contiguous, child_tree)
    else
      local last_end = contiguous[#contiguous]:data().range[3]
      local current_start = child_pos.range[1]

      -- Check for conflicts between last_end and current_start
      local has_conflict = false
      for line = last_end + 1, current_start - 1 do
        local owner = method_ownership_map[line]
        if owner and owner ~= current_suite_name then
          has_conflict = true
          break
        end
      end

      if has_conflict then
        table.insert(conflicting, child_tree)
      else
        table.insert(contiguous, child_tree)
      end
    end
  end

  -- Adjust namespace range to span only contiguous children
  namespace_pos.range[1] = first_contiguous.range[1]
  namespace_pos.range[3] = max(last_contiguous.range[3], namespace_pos.range[3])

  return contiguous, conflicting
end
```

**3. Usage** (lines 531-547, 652-666):
```lua
-- Process each suite
for suite_function, suite_pos in pairs(suite_functions) do
  local suite_children = process_suite(...)

  -- Detect conflicts
  local contiguous_children, conflicting_children =
    separate_by_conflicts(suite_children, suite_function, suite_pos)

  -- Add namespace with only contiguous children
  if #contiguous_children > 0 then
    table.insert(root_children, create_tree_node(suite_pos, contiguous_children))
  end

  -- Add conflicting children to root level (but keep suite ID)
  for _, child in ipairs(conflicting_children) do
    table.insert(root_children, child)
  end
end
```

---

## Why This Works

### 1. No Arbitrary Thresholds

**Gap logic:** "Separate methods >20 lines apart"
- Why 20? Could be 10, 50, 100...
- Hard to explain to users

**Smart conflict detection:** "Separate when another suite's method is in the way"
- Clear reasoning based on actual data
- Easy to understand

### 2. Uses Lookup Table Intelligently

The lookup table already provides:
- ✅ Classification: which methods belong to which suite
- ✅ Line ranges: where each method is defined
- ✅ Cross-file tracking: methods defined elsewhere

We leverage this data to build the ownership map and detect conflicts.

### 3. More Precise

**Gap logic:**
- Methods 100 lines apart → **always separated** (even if no conflict)
- Unnecessarily breaks up suites

**Smart conflict detection:**
- Methods 100 lines apart → **grouped together** (if no conflict)
- Only separates when necessary

### 4. Correct Execution Preserved

Methods moved to root level:
- ✅ Keep their suite ID (e.g., `path::TestExampleTestSuite::TestSubTestOperand1`)
- ✅ Still execute correctly with `go test -run TestExampleTestSuite/TestSubTestOperand1`
- ✅ User can still run them individually

### 5. Solves the Real Problem

**The real problem:** Namespace ranges overlapping, causing `nearest` algorithm to enter wrong namespace.

**The solution:** Detect overlaps using actual data, adjust namespace ranges to prevent conflicts.

---

## Trade-offs

### Advantages

✅ **No arbitrary thresholds** - decision based on actual conflicts
✅ **Uses lookup data intelligently** - leverages existing classification
✅ **More precise** - only separates when necessary
✅ **Easy to explain** - "another suite's method is in the way"
✅ **Correct execution** - all tests still runnable
✅ **Scalable** - works for any number of suites in a file

### Disadvantages

⚠️ **Slightly more complex** - requires building ownership map and checking conflicts
⚠️ **Methods at root level** - might surprise users (but still work correctly)
⚠️ **Depends on lookup quality** - requires accurate lookup table data

### Comparison to Alternatives

| Approach | Pros | Cons |
|---|---|---|
| **No separation** | Simple | Namespace overlap breaks "nearest test" |
| **Gap logic (20 lines)** | Works, simple threshold | Arbitrary, separates unnecessarily |
| **Smart conflict detection** ✓ | Precise, data-driven, no arbitrary threshold | Slightly more complex |
| **Flatten tree** | Simple, no overlaps | Loses hierarchy, namespace is just marker |

---

## Conclusion

The smart conflict detection approach successfully solves the "run nearest test" issue by:

1. **Using the lookup table** to build a method ownership map
2. **Detecting actual conflicts** when another suite's methods appear between a suite's methods
3. **Adjusting namespace ranges** to span only contiguous (non-conflicting) methods
4. **Moving conflicting methods** to root level while preserving their suite ID

This solution is:
- ✅ More precise than arbitrary gap thresholds
- ✅ Uses existing data intelligently
- ✅ Easy to understand and explain
- ✅ Proven by passing all tests

The key insight: **We don't need arbitrary thresholds when we have actual data about what conflicts exist.**
