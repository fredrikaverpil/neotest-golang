# Understanding Neotest's "Run Nearest Test" Algorithm

This document explains how Neotest's `nearest` algorithm works and why namespace ranges are critical for correct testify suite support.

## Table of Contents

- [The Nearest Algorithm](#the-nearest-algorithm)
- [How It Works](#how-it-works)
- [The Testify Suite Problem](#the-testify-suite-problem)
- [Why Namespace Ranges Matter](#why-namespace-ranges-matter)
- [Potential Solutions](#potential-solutions)

---

## The Nearest Algorithm

From `.tests/all/site/pack/deps/start/neotest/lua/neotest/lib/positions/init.lua`:

```lua
function neotest.lib.positions.nearest(tree, line)
  local nearest = tree
  for _, node in tree:iter_nodes() do  -- Depth-first pre-order traversal
    local pos = node:data()
    if pos.range then
      if line >= pos.range[1] then
        nearest = node
      else
        return nearest  -- STOPS when finding first node starting after cursor
      end
    end
  end
  return nearest
end
```

**Key behaviors:**
1. **Depth-first pre-order traversal**: Parent, then children (left to right)
2. **Checks if cursor line >= node start line**: Updates "nearest" if true
3. **Returns immediately**: When it finds a node that starts AFTER the cursor line
4. **Never backtracks**: Once it enters a namespace, it stays within that subtree until finding a node after cursor

---

## How It Works

**Example tree:**
```
File (0-100)
├─ TestSuite (namespace, 20-40)
│  ├─ TestMethod1 (20-25)
│  └─ TestMethod2 (30-35)
└─ TestRegular (50-55)
```

**Cursor at line 32:**
1. File (0): `32 >= 0`? ✓ → nearest = File
2. TestSuite (20): `32 >= 20`? ✓ → nearest = TestSuite, **enters namespace**
3. TestMethod1 (20): `32 >= 20`? ✓ → nearest = TestMethod1
4. TestMethod2 (30): `32 >= 30`? ✓ → nearest = TestMethod2 ✓
5. TestRegular (50): `32 >= 50`? ✗ → **RETURNS TestMethod2**

**Result:** Correctly finds TestMethod2 ✓

---

## The Testify Suite Problem

### The Actual File Structure

`tests/features/internal/testifysuites/positions_test.go`:

```go
type ExampleTestSuite struct { suite.Suite }

func (suite *ExampleTestSuite) TestExample() {      // line 27-29
    assert.Equal(suite.T(), 5, suite.VariableThatShouldStartAtFive)
}

func (suite *ExampleTestSuite) TestExample2() {     // line 31-33
    assert.Equal(suite.T(), 5, suite.VariableThatShouldStartAtFive)
}

func TestExampleTestSuite(t *testing.T) {           // line 37-39
    suite.Run(t, new(ExampleTestSuite))
}

// --------------------------------------------------------------------

type ExampleTestSuite2 struct { suite.Suite }

func (suite *ExampleTestSuite2) TestExample() {    // line 54-56
    assert.Equal(suite.T(), 5, suite.VariableThatShouldStartAtFive)
}

func (suite *ExampleTestSuite2) TestExample2() {   // line 58-60
    assert.Equal(suite.T(), 5, suite.VariableThatShouldStartAtFive)
}

func TestExampleTestSuite2(t *testing.T) {         // line 62-64
    suite.Run(t, new(ExampleTestSuite2))
}

// Later in file...

func (suite *ExampleTestSuite) TestSubTestOperand1() {  // line 83-88
    suite.Run("subtest", func() { ... })
}

func (s *ExampleTestSuite) TestSubTestOperand2() {      // line 91-96
    s.Run("subtest", func() { ... })
}
```

### The Tree Structure (Without Gap Logic)

When we adjust namespace ranges to include ALL methods (simplest fix):

```
File (0-97)
├─ TestExampleTestSuite (namespace, range [27, 96])  ← Spans ALL ExampleTestSuite methods
│  ├─ TestExample (27-29)
│  ├─ TestExample2 (31-33)
│  ├─ TestSubTestOperand1 (83-88)
│  └─ TestSubTestOperand2 (91-96)
├─ TestExampleTestSuite2 (namespace, range [54, 64])  ← Second suite
│  ├─ TestExample (54-56)
│  └─ TestExample2 (58-60)
└─ TestTrivial (69-71)
```

### The Bug: Cursor at Line 54

**User places cursor at line 54**: Where `ExampleTestSuite2.TestExample` is defined

**Algorithm execution:**
1. File (0): `54 >= 0`? ✓ → nearest = File
2. **TestExampleTestSuite (27)**: `54 >= 27`? ✓ → nearest = TestExampleTestSuite, **enters namespace**
3. TestExample (27): `54 >= 27`? ✓ → nearest = TestExample
4. **TestExample2 (31)**: `54 >= 31`? ✓ → nearest = TestExample2 ✓
5. TestSubTestOperand1 (83): `54 >= 83`? ✗ → **RETURNS TestExample2**

**Result:** Runs `TestExampleTestSuite/TestExample2` instead of `TestExampleTestSuite2/TestExample` ✗

**The algorithm NEVER reaches TestExampleTestSuite2** because:
- It entered `TestExampleTestSuite` namespace (54 >= 27)
- Found a match inside that namespace (TestExample2 at line 31)
- Stopped when reaching TestSubTestOperand1 at line 83
- Never backtracked to check TestExampleTestSuite2

---

## Why Namespace Ranges Matter

### The Critical Issue

**Namespace ranges determine which namespace the algorithm enters.**

If a namespace range includes line 54:
- Algorithm enters that namespace
- Checks only the children of that namespace
- Stops when finding first child starting after line 54
- Never checks sibling namespaces

**In our case:**
- `TestExampleTestSuite` namespace range: `[27, 96]`
- This range includes line 54 (where `ExampleTestSuite2.TestExample` is defined)
- Algorithm enters the WRONG namespace
- Finds TestExample2 at line 31 (wrong suite!)
- Never gets to check `TestExampleTestSuite2` namespace

### What the Methods Already Have

**The test methods have CORRECT line ranges from tree-sitter:**
- `ExampleTestSuite.TestExample`: lines 27-29 ✓
- `ExampleTestSuite.TestExample2`: lines 31-33 ✓
- `ExampleTestSuite2.TestExample`: lines 54-56 ✓
- `ExampleTestSuite2.TestExample2`: lines 58-60 ✓

**The problem is NOT the method ranges. The problem is the NAMESPACE range that's too large.**

---

## Potential Solutions

### Solution 1: Restore Gap Logic (MAX_GAP = 20)

Separate methods that are >20 lines apart into "non-contiguous" groups:

```
File (0-97)
├─ TestExampleTestSuite (namespace, range [27, 37])  ← Only contiguous methods!
│  ├─ TestExample (27-29)
│  └─ TestExample2 (31-33)
├─ TestExampleTestSuite2 (namespace, range [54, 64])
│  ├─ TestExample (54-56)
│  └─ TestExample2 (58-60)
├─ TestTrivial (69-71)
├─ TestSubTestOperand1 (83-88, ID: path::TestExampleTestSuite::TestSubTestOperand1)  ← Root level
└─ TestSubTestOperand2 (91-96, ID: path::TestExampleTestSuite::TestSubTestOperand2)  ← Root level
```

**Cursor at line 54:**
1. File (0): `54 >= 0`? ✓
2. TestExampleTestSuite (27): `54 >= 27`? ✓ **enters namespace**
3. TestExample (27): `54 >= 27`? ✓
4. TestExample2 (31): `54 >= 31`? ✓
5. **TestExampleTestSuite2 (54)**: `54 >= 54`? ✓ **exits first namespace, enters second** ✓
6. TestExample (54): `54 >= 54`? ✓ → **Returns TestExample** ✓

**Pros:**
- Fixes the overlap issue
- Non-contiguous methods still executable (keep suite ID)
- Namespace ranges accurately reflect "related" code clusters

**Cons:**
- Arbitrary threshold (why 20 lines?)
- More complex code (~80 lines)
- Methods at root level might surprise users
- Hard to explain

### Solution 2: Don't Nest Methods Under Namespaces

Keep all methods at root level, just modify their IDs:

```
File (0-97)
├─ TestExampleTestSuite (namespace, range [37-39], no children)
├─ TestExample (27-29, ID: path::TestExampleTestSuite::TestExample)
├─ TestExample2 (31-33, ID: path::TestExampleTestSuite::TestExample2)
├─ TestExampleTestSuite2 (namespace, range [62-64], no children)
├─ TestExample (54-56, ID: path::TestExampleTestSuite2::TestExample)
├─ TestExample2 (58-60, ID: path::TestExampleTestSuite2::TestExample2)
└─ TestTrivial (69-71)
```

**Pros:**
- Simple algorithm (no gap logic needed)
- No namespace overlap issues
- Methods have correct line ranges

**Cons:**
- Namespaces are "empty" (just markers)
- Tree structure doesn't show "belongs to" relationship
- Less intuitive for users

### Solution 3: Smart Namespace Ranges Using Lookup

Use the lookup table to calculate precise namespace boundaries:
- For each suite, find ALL methods (including non-contiguous ones)
- Calculate namespace range: `[min(methods), max(methods, suite_function)]`
- Check for overlaps with other suite namespaces
- Split overlapping methods to root level

**Pros:**
- Uses lookup table data intelligently
- Only separates methods when necessary (actual overlaps)
- More precise than arbitrary 20-line threshold

**Cons:**
- More complex overlap detection logic
- Still results in some methods at root level
- Requires comparing all suite namespace ranges

### Solution 4: Use End Range Check

Modify tree structure so namespace end range matters:
- Namespace range: `[first_method, last_contiguous_method]`
- Only enter namespace if: `cursor >= start AND cursor <= end`

**Cons:**
- Would require modifying Neotest's `nearest` algorithm (can't do this!)
- Not our code to change

---

## Recommendations

Given the constraints:

1. **Restore gap logic** (Solution 1) is the most pragmatic:
   - Solves the overlap problem
   - Keeps code in neotest-golang (don't modify Neotest itself)
   - Non-contiguous methods still work correctly

2. **Make MAX_GAP configurable**:
   - Add option: `testify.max_contiguous_gap = 20` (default)
   - Users can adjust if needed
   - Document why this exists

3. **Better documentation**:
   - Explain that gap logic prevents namespace overlap
   - Show that non-contiguous methods still execute correctly
   - Document as "namespace range optimization" not "tree structure preference"

---

## Key Takeaway

**The lookup table provides correct classification** (which methods belong to which suite).

**The gap logic provides correct execution** (which namespace the `nearest` algorithm enters).

Both are needed for testify suite support to work correctly.
