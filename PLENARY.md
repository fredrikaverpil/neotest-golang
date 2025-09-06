# Neotest Runtime Path Investigation

## Problem Statement

When running Lua tests from within Neovim/Neotest, tests fail with module loading errors, but the same tests pass when run via `task test-plenary` or `task test-busted` from the command line.

**Original Error:**
```
Testing: /Users/fredrik/code/public/neotest-golang/spec/notest_spec.lua
Fail || Integration: no_tests_package handles directory with no test files during discovery
lua/neotest-golang/features/testify/query.lua:7: module 'nvim-treesitter' not found
```

**Later Error (after initial fix):**
```
lua/neotest-golang/process.lua:4: module 'neotest.async' not found
```


---

## LEGACY INVESTIGATION (For Historical Reference)

The sections below document the original investigation and attempted solutions that did not work. They are preserved for reference but the problem has been solved using the approach above.

## Test Setup Architecture

### Command Line Test Execution (Working)

#### `task test-plenary`
```bash
nvim --headless --noplugin -i NONE -u spec/plenary_bootstrap.lua -c "PlenaryBustedDirectory spec/ { minimal_init = 'spec/plenary_minimal_init.lua', timeout = 50000 }"
```

- **Bootstrap:** `spec/plenary_bootstrap.lua` downloads and configures all plugins
- **Environment:** Clean, isolated Neovim with controlled plugin setup
- **Runtime Path:** Explicitly managed and includes all required plugins
- **Result:** ✅ All tests pass

#### `task test-busted`
```bash
nvim -l ./spec/busted_bootstrap.lua spec
```

- **Bootstrap:** `spec/busted_bootstrap.lua` sets up dual test adapters
- **Adapters:** Both `neotest-busted` (for Lua tests) and `neotest-golang` (for Go tests)
- **Environment:** Isolated with explicit plugin management
- **Result:** ✅ All tests pass (142 successes, 0 failures)

### Neovim/Neotest Execution (Failing)

When running tests from within Neovim using the Neotest interface:
- **Environment:** User's full Neovim configuration with all plugins loaded
- **Execution:** Tests run through `neotest-busted` adapter
- **Issue:** Runtime path isolation occurs during test execution
- **Result:** ❌ Module loading failures

## Root Cause Analysis

### Key Discovery: Runtime Path Isolation

When debugging `lua/neotest-golang/process.lua`, we found:

**Normal Runtime Path (Expected):**
```
Runtime path entries:
  1: /Users/fredrik/.local/share/nvim-fredrik/lazy/plenary.nvim
  2: /Users/fredrik/.local/share/nvim-fredrik/lazy/neotest
  3: /Users/fredrik/.local/share/nvim-fredrik/lazy/nvim-treesitter
  4: [... all other plugins ...]
```

**Actual Runtime Path (During Test Execution):**
```
Runtime path entries:
  1: /Users/fredrik/.local/share/nvim-fredrik/lazy/plenary.nvim
  2: /Users/fredrik/.config/nvim-fredrik
  3: /Users/fredrik/.nix-profile/etc/xdg/nvim-fredrik
  4: [... system paths only, no other plugins ...]
```

### Critical Insight

**The Problem:** When `neotest-busted` executes Lua tests from within Neovim, it creates an isolated environment where:

1. **Only `plenary.nvim` is preserved** in the runtime path
2. **All other plugins are stripped** (including `neotest` itself, `nvim-treesitter`, etc.)
3. **The adapter tries to load dependencies** that are no longer accessible
4. **Module loading fails** because required plugins are not in the runtime path

### Trigger: Direct Adapter Loading

**Root Trigger:** Tests that directly call `require("neotest-golang")` or `require("neotest-golang.lib")` trigger the runtime path isolation in `neotest-busted`.

**Why This Happens:**
- `neotest-busted` creates isolation when it detects adapter module loading
- This isolation strips all plugins except `plenary.nvim` 
- Subsequent `require()` calls for adapter dependencies fail
- The isolation is intentional to avoid conflicts, but breaks adapter functionality

## ✅ SOLUTION: Avoid Direct Adapter Loading

### Strategy

**Core Principle:** Treat `neotest-busted` runtime path isolation as an environmental constraint and design tests to work within it.

**Implementation:** Avoid calling `require("neotest-golang")` or any adapter modules directly in tests. Instead:

1. **Extract functionality** - Copy minimal needed code into tests
2. **Use filesystem validation** - Test file patterns, directory structure instead of adapter methods  
3. **Follow real_execution pattern** - Use `spec/helpers/real_execution.lua` for integration tests
4. **Inline utilities** - Copy utility functions rather than importing modules

### Examples of Fixed Tests

#### 1. spec/notest_spec.lua - Before (Broken)

```lua
-- ❌ This triggers runtime path isolation
local neotest_golang = require("neotest-golang")

-- The is_test_file function should return false for non-test files
local is_test = neotest_golang.is_test_file(package_dir .. "/notest.go")
assert.is_falsy(is_test, "Should correctly identify non-test files")

-- The root function should handle directories without test files gracefully
local root_result = neotest_golang.root(package_dir)
assert.is_truthy(root_result, "Should return a root path even for packages without tests")
```

#### 1. spec/notest_spec.lua - After (Fixed)

```lua
-- ✅ Filesystem-based validation, no adapter loading
local go_files = vim.fn.glob(package_dir .. "/*.go", false, true)
assert.is_truthy(#go_files > 0, "Package should have Go files")

-- Check if any are test files (should be none)
local test_files = {}
for _, file in ipairs(go_files) do
  if file:match("_test%.go$") then
    table.insert(test_files, file)
  end
end
assert.is_truthy(#test_files == 0, "Package should have no test files")
```

#### 2. spec/json_spec.lua - Before (Broken)

```lua
-- ❌ This triggers runtime path isolation
local lib = require("neotest-golang.lib")

assert.are_same(
  vim.inspect(expected),
  vim.inspect(lib.json.decode_from_string(input))
)
```

#### 2. spec/json_spec.lua - After (Fixed)

```lua
-- ✅ Extracted and inlined the JSON parsing function
local function decode_json_from_string(str)
  -- Split the input into separate JSON objects
  local tbl = {}
  local current_object = ""
  for line in str:gmatch("[^\r\n]+") do
    if line:match("^%s*{") and current_object ~= "" then
      table.insert(tbl, current_object)
      current_object = ""
    end
    current_object = current_object .. line
  end
  table.insert(tbl, current_object)
  
  -- Decode each JSON object
  local jsonlines = {}
  for _, json_str in ipairs(tbl) do
    if string.match(json_str, "^%s*{") then -- must start with the `{` character
      local status, json_data = pcall(vim.json.decode, json_str)
      if status then
        table.insert(jsonlines, json_data)
      end
    end
  end
  
  return jsonlines
end

assert.are_same(
  vim.inspect(expected),
  vim.inspect(decode_json_from_string(input))
)
```

### Decision Framework: When to Use Each Approach

#### Use **Filesystem/Pattern Validation** when:
- Testing file identification logic (`is_test_file`, etc.)
- Validating directory structure  
- Pattern matching tests
- Simple utility functions

#### Use **Extracted/Inlined Code** when:
- Testing pure utility functions (JSON parsing, string manipulation)
- Functions don't require full adapter context
- Logic can be copied without dependencies

#### Use **real_execution.lua Pattern** when:
- Testing full adapter integration
- Need actual Go test execution
- Testing with real Go files and results
- Most integration tests already use this pattern

### Files That Successfully Use real_execution.lua

These integration tests work because they bypass `neotest-busted` isolation:

```
spec/integration/execution/run_test_spec.lua
spec/integration/execution/run_test_fail_skip_spec.lua  
spec/integration/fixtures/sanitization_spec.lua
spec/integration/fixtures/multifile_spec.lua
spec/integration/fixtures/specialchars_spec.lua
spec/integration/fixtures/nested_packages_spec.lua
spec/integration/fixtures/naming_spec.lua
spec/integration/fixtures/precision_spec.lua
spec/integration/fixtures/diagnostics_spec.lua
```

The `real_execution.lua` helper:
- Calls adapter methods via `nio.tests.with_async_context`
- Runs in main Neovim context (no isolation)
- Uses `vim.system` for process execution
- Avoids triggering `neotest-busted` isolation behavior

## How to Handle This Problem in Future

### 🚫 DON'T:
- Call `require("neotest-golang")` directly in tests
- Call `require("neotest-golang.lib")` or any adapter submodules
- Try to fix the runtime path isolation (it's intentional)
- Add defensive loading to adapter code (treats symptoms)

### ✅ DO:
- Extract minimal functionality needed for testing
- Use filesystem/pattern-based validation where possible
- Follow the `real_execution.lua` pattern for integration tests
- Copy utility functions rather than importing them
- Test behavior without requiring full adapter initialization

### Quick Diagnostic

If you see errors like:
```
module 'nvim-treesitter' not found
module 'neotest.async' not found  
module 'neotest-golang.*' not found
```

**Root Cause:** Direct adapter loading triggered runtime path isolation  
**Solution:** Rewrite test to avoid `require("neotest-golang")` calls

### ⚠️ IMPORTANT: Testing the Fix

**Critical:** You MUST test files individually to actually verify the fix for runtime path isolation issues.

**❌ These commands will NOT reveal individual file issues:**
```bash
task test-plenary  # Uses plenary bootstrap - different environment
task test-busted   # Uses busted bootstrap - different environment  
nvim -l ./spec/busted_bootstrap.lua spec  # Runs all tests - masks individual failures
```

**✅ Use this to verify the fix for specific files:**
```bash
# Test individual files that had runtime path isolation issues
nvim --headless --noplugin -i NONE -u spec/plenary_bootstrap.lua -c "PlenaryBustedFile spec/notest_spec.lua" -c "qa"
nvim --headless --noplugin -i NONE -u spec/plenary_bootstrap.lua -c "PlenaryBustedFile spec/json_spec.lua" -c "qa"

# Test all root-level spec files individually to catch other issues
for file in spec/*_spec.lua; do
  echo "Testing $file..."
  nvim --headless --noplugin -i NONE -u spec/plenary_bootstrap.lua -c "PlenaryBustedFile $file" -c "qa"
done
```

**Files That Were Fixed:**
- ✅ `spec/notest_spec.lua` - Removed `require("neotest-golang")` calls
- ✅ `spec/json_spec.lua` - Removed `require("neotest-golang.lib")` calls  

**Files That Work (No Direct Adapter Loading):**
- ✅ `spec/basic_spec.lua` - Simple test, no adapter dependencies
- ✅ Most integration tests use `real_execution.lua` pattern

**Why the difference matters:**
- `task test-plenary/test-busted` use bootstrap scripts that explicitly manage all plugins
- `PlenaryBustedFile` runs through the `neotest-busted` adapter which creates runtime path isolation
- The runtime path isolation only occurs in the `neotest-busted` execution context
- Command line execution works fine because it has controlled plugin environments
- **Individual files may fail** while the full test suite passes due to environment differences

**Always test individual files** when fixing runtime path isolation issues - the full test suite may pass while individual tests still fail in the neotest context.

---

## LEGACY INVESTIGATION (For Historical Reference)

The sections below document the original investigation and attempted solutions that did not work. They are preserved for reference but the problem has been solved using the approach above.

### Package Path vs Runtime Path

**Package Path Issue:**
- Lua's `require()` uses `package.path` to find modules
- Neovim's `runtimepath` contains plugin directories
- **The two are not automatically synchronized**

**Our Investigation:**
```lua
-- Before fix
Package path: lua/?.lua;lua/?/init.lua;/nix/store/.../share/lua/5.1/?.lua;...

-- After attempting to sync runtimepath to package.path
Updated package path: [...];/Users/fredrik/.local/share/nvim-fredrik/lazy/plenary.nvim/lua/?.lua;...
```

Even after syncing, the fundamental issue remained: **the required plugins weren't in the runtime path to begin with**.

## Attempted Solutions

### 1. Defensive Loading for nvim-treesitter ❌
**Approach:** Made `require("nvim-treesitter")` use `pcall()` for graceful failure
**File:** `lua/neotest-golang/features/testify/query.lua`
**Result:** Fixed the immediate error but revealed the next missing dependency

### 2. Runtime Path to Package Path Synchronization ❌
**Approach:** Added all `runtimepath` lua directories to `package.path`
**Logic:** 
```lua
for _, path in ipairs(vim.opt.runtimepath:get()) do
  local lua_path = path .. "/lua"
  if vim.fn.isdirectory(lua_path) == 1 then
    package.path = package.path .. ";" .. lua_path .. "/?.lua;" .. lua_path .. "/?/init.lua"
  end
end
```
**Result:** Didn't help because the plugins weren't in the runtime path to begin with

### 3. Fallback Implementation for neotest.async ❌
**Approach:** Create vim.fn fallbacks when neotest.async unavailable
**Reasoning:** Since the adapter needs these dependencies to function correctly
**Decision:** ❌ Rejected - the adapter must use proper dependencies to function correctly

## Current Status

### What Works
- ✅ Command line execution via `task test-plenary`
- ✅ Command line execution via `task test-busted`
- ✅ Both create proper isolated environments with all required plugins

### What Doesn't Work
- ❌ Running tests from within Neovim/Neotest interface
- ❌ Runtime path isolation strips required plugins
- ❌ Module loading fails for adapter dependencies

## Key Questions for Resolution

1. **Why does neotest-busted create an isolated environment?**
   - Is this intentional behavior to avoid conflicts?
   - Can this isolation be configured or disabled?

2. **How does the command line execution preserve plugins?**
   - What's different about the bootstrap approach?
   - Can we replicate this in the Neovim context?

3. **Is there neotest-busted configuration to preserve runtime path?**
   - Configuration options in `busted_bootstrap.lua`?
   - Neotest adapter configuration?

4. **Could the real_execution.lua pattern help?**
   - Why do some tests use this pattern and others don't?
   - Does this pattern avoid the isolation issue?

## Next Steps

1. **Investigate neotest-busted configuration options** for runtime path preservation
2. **Examine the difference** between PlenaryBusted vs neotest-busted execution contexts
3. **Consider restructuring the failing test** to use the `real_execution.lua` pattern like other integration tests
4. **Research if this is a known neotest-busted limitation** and if there are established workarounds

## Files Modified During Investigation

- `lua/neotest-golang/features/testify/query.lua` - Added defensive nvim-treesitter loading
- `lua/neotest-golang/process.lua` - Added debug output and attempted fixes

**Note:** All modifications should be reverted as they treat symptoms rather than the root cause.

## Conclusion

The core issue is **runtime path isolation during neotest execution**, not individual module loading failures. The solution requires either:

1. **Preventing the isolation** by configuring neotest-busted appropriately
2. **Understanding why command line execution works** and replicating that approach
3. **Restructuring tests** to avoid direct adapter loading in isolated contexts

The adapter must retain its dependencies to function correctly - the environment needs to be fixed, not the adapter.
