# Neotest-Golang Test Strategy Refactoring TODO

## 🚨 FRESH CONTEXT INSTRUCTIONS

**If starting with a fresh LLM context window, read this first:**

1. **This is a Neovim plugin** called `neotest-golang` - a Go test adapter for
   the Neotest framework
2. **Project location**: `/Users/fredrik/code/public/neotest-golang/`
3. **Key commands to know**:
   - `task test-plenary` - Runs the Lua integration tests (our main test suite)
   - `task format` - Formats code with stylua
   - `cd tests/go && go test ./...` - Runs Go fixtures (should have some
     intentional failures)
4. **Current working directory**: Always
   `cd /Users/fredrik/code/public/neotest-golang` first
5. **Testing strategy**: Go files in `tests/go/` are test fixtures/data, NOT
   real tests. Lua files in `tests/integration/` are the real tests.
6. **Main tools available**: `read`, `write`, `edit`, `bash`, `list`, `glob`,
   `grep`
7. **Recent major win**: We completely resolved a gotestsum hanging issue that
   was blocking the test suite
8. Always add checkboxes in this TODO.md file and tick them as you are done with
   the task.
9. Apply formatting and add a git commit everytime all tests are passing, so you
   have a good point to revert back to in case of getting stuck and to avoid a
   mess.

## Context & Background

We are refactoring the testing strategy for the neotest-golang adapter.
Previously, we had a mix of Go tests and Lua tests. Now we're evolving to a
cleaner approach where:

- **Go test fixtures** in `tests/go/` are pure test data/fixtures (not actual CI
  tests)
- **Lua integration tests** are the real tests that run in CI via
  `task test-plenary`
- Go fixtures represent various real-world scenarios the adapter needs to handle
- Each Go fixture serves a specific testing purpose for the adapter

## Current Status

✅ **Completed:**

- Resolved gotestsum hanging issue completely
- Fixed lookup test failures
- Identified all Go test fixtures and their purposes
- Created comprehensive plan for 100% test coverage
- **✅ MAJOR WIN**: Fixed all legacy reference issues in test infrastructure
- **✅ Infrastructure Migration**: All directory structure mismatches resolved
- **✅ Test Stability**: All tests now pass (`task test-plenary` successful)

🔄 **Ready for Next Phase:**

- **READY TO START**: Phase 2.1 - Migrate from Co-location to Mirrored Structure
- Foundation is now stable for Go-conventional naming migration

## Critical Implementation Notes

### 🚨 GOLDEN RULE: Always run `task test-plenary` between each edit

**This cannot be overstated**: After ANY change (renaming, editing files,
creating new tests), immediately run:

```bash
cd /Users/fredrik/code/public/neotest-golang
task test-plenary
```

If tests fail after your change, fix it immediately before proceeding. This
prevents cascading failures and makes debugging much easier.

### Before Starting Any Work:

1. **Always test current state first**:

   ```bash
   cd /Users/fredrik/code/public/neotest-golang
   task test-plenary  # Should pass (main test suite)
   task format        # Should pass (code formatting)
   ```

2. **After making changes, always verify**:

   ```bash
   task test-plenary  # Ensure no regressions
   task format        # Fix any formatting issues
   ```

3. **Workflow for ANY change**:
   - Make one small change
   - Run `task test-plenary`
   - If it passes → continue
   - If it fails → fix immediately before proceeding

### Understanding the codebase:

- `lua/neotest-golang/` - Main adapter code
- `tests/go/` - Go test fixtures (test data, not real tests)
- `tests/integration/` - Lua integration tests (real tests)
- `tests/helpers/` - Shared test utilities

### Integration Test Template:

When creating new integration tests in the mirrored structure, use this pattern:

```lua
local _ = require("plenary")
local options = require("neotest-golang.options")

-- Load real execution helper
local real_execution_path = vim.uv.cwd() .. "/tests/helpers/real_execution.lua"
local real_execution = dofile(real_execution_path)

describe("Integration: [fixture_name]", function()
  it("[test_description]", function()
    options.set({ runner = "go", warn_test_results_missing = false })

    -- NOTE: Path points to Go fixture in mirrored structure
    local test_filepath = vim.uv.cwd() .. "/tests/go/internal/[fixture_name]/[fixture_test].go"
    test_filepath = real_execution.normalize_path(test_filepath)

    local tree, results = real_execution.execute_adapter_direct(test_filepath)

    -- Add specific assertions based on what the fixture tests
    assert.is_truthy(tree)
    assert.is_truthy(results)
  end)
end)
```

**Key changes from co-location:**

- Integration test file location:
  `tests/integration/fixtures/[fixture_name]_spec.lua`
- Go fixture path: `tests/go/internal/[fixture_name]/[fixture_test].go`
- Clear separation: Lua tests point to Go fixtures, but live separately

### Renaming Safety Protocol:

When renaming directories:

1. Use `git mv` for proper Git tracking
2. Update any hardcoded paths in Lua files
3. Check `tests/go/lookup_spec.lua` for path references
4. Run tests after each rename to catch issues early

### 🚨 CRITICAL: Preserve Go Testing Patterns - DO NOT LOSE THIS:

**Essential Go toolchain distinction that MUST be preserved:**

- [ ] **Verify XTestGoFiles vs GoTestFiles detection still works after
      renaming**
  - **Current location**: `package_naming/` directory
  - **Files to preserve**:
    - `xtest.go` (package package_naming) - provides exported functions
    - `whitebox_test.go` (package package_naming) - creates **GoTestFiles**
      (internal testing)
    - `blackbox_test.go` (package package_naming_test) - creates
      **XTestGoFiles** (external testing)
  - **Critical difference**:
    - `whitebox_test.go`: Same package, can access internal functions like
      `internal()`
    - `blackbox_test.go`: Different package (`_test` suffix), only public API
      access
  - **Why this matters**: Go toolchain categorizes these differently, adapter
    must handle both
  - **Test coverage**: Ensures adapter correctly detects and handles both test
    types
  - **After migration**: Verify spec file tests both whitebox and blackbox
    scenarios

**🚨 DO NOT change package declarations in these files - they implement
essential Go patterns!**

### Test Organization Strategy:

**✅ Use mirrored directory structure for clean separation:**

- **Go directories**: Pure fixtures only (`.go` files following Go conventions)
- **Lua directories**: Mirror structure in `tests/integration/fixtures/`
- Clear 1:1 relationships: `diagnostics/` fixture → `diagnostics_spec.lua` test
- Benefits over co-location:
  - Clean separation of concerns (fixtures vs tests)
  - Go directories follow Go conventions (no mixed file types)
  - Easy navigation with mirrored structure
  - Maintains clear fixture-to-test relationships
- Examples:
  - Go fixture: `tests/go/internal/diagnostics/diagnostics_test.go`
  - Lua test: `tests/integration/fixtures/diagnostics_spec.lua`
- Keep general tests in their current locations:
  - `tests/unit/` for adapter unit tests
  - `tests/integration/` for complex cross-fixture integration tests
  - `tests/go/lookup_spec.lua` for general Go tooling tests

## Phase 1: Rename Go Test Fixtures for Clarity

### Current → Proposed Renaming:

- [x] `diagnostics/` → `diagnostic_classification/`
  - [x] `diagnostics_test.go` → `diagnostic_classification_test.go`
  - **Purpose**: Tests hint vs error message classification

- [x] `operand/` → `treesitter_precision/`
  - [x] `operand_test.go` → `treesitter_precision_test.go`
  - **Purpose**: Tests treesitter query precision (real t.Run vs method calls)

- [x] `sanitization/` → `output_sanitization/`
  - [x] `sanitize_test.go` → `output_sanitization_test.go`
  - **Purpose**: Tests binary/garbage output handling

- [x] `testname/` → `special_characters/`
  - [x] `testname_test.go` → `special_characters_test.go`
  - **Purpose**: Tests test names with special characters/regex chars

- [x] `x/` → `package_naming/`
  - [x] `xtest_blackbox_test.go` → `blackbox_test.go`
  - [x] `xtest_whitebox_test.go` → `whitebox_test.go`
  - **Purpose**: Tests `*_test` vs same package naming

- [x] `two/` → `multi_file_package/`
  - [x] `one_test.go` → `first_file_test.go`
  - [x] `two_test.go` → `second_file_test.go`
  - **Purpose**: Tests packages with multiple test files

- [x] `notest/` → `no_tests_package/`
  - **Purpose**: Tests handling packages without any tests

- [x] `subpackage/` → `nested_packages/`
  - **Purpose**: Tests nested directory structure discovery

- [x] `fail_skip*/` → `test_state_behaviors/`
  - [x] Consolidate fail_skip, fail_skip_passing, fail_skip_skipping
  - **Purpose**: Tests pass/fail/skip state detection

- [x] `positions/` → `position_discovery/`
  - **Purpose**: Tests position discovery for various test structures

- [x] `testify/` → `testify_suites/`
  - **Purpose**: Tests testify suite integration

### Renaming Commands (use git mv for proper tracking):

```bash
cd /Users/fredrik/code/public/neotest-golang/tests/go/internal/

# Rename directories with git mv for proper tracking
git mv diagnostics diagnostic_classification
git mv operand treesitter_precision
git mv sanitization output_sanitization
git mv testname special_characters
git mv x package_naming
git mv two multi_file_package
git mv notest no_tests_package
git mv subpackage nested_packages
git mv positions position_discovery
git mv testify testify_suites

# Rename individual files within directories
cd diagnostic_classification && git mv diagnostics_test.go diagnostic_classification_test.go && cd ..
cd treesitter_precision && git mv operand_test.go treesitter_precision_test.go && cd ..
cd output_sanitization && git mv sanitize_test.go output_sanitization_test.go && cd ..
cd special_characters && git mv testname_test.go special_characters_test.go && cd ..
cd package_naming && git mv xtest_blackbox_test.go blackbox_test.go && git mv xtest_whitebox_test.go whitebox_test.go && cd ..
cd multi_file_package && git mv one_test.go first_file_test.go && git mv two_test.go second_file_test.go && cd ..

# Test after renaming
cd /Users/fredrik/code/public/neotest-golang
task test-plenary
```

## 🚨 IMMEDIATE NEXT PHASE: Foundation Cleanup

### Why This Must Come First:

- Current co-located structure violates Go conventions (mixed file types)
- Package names with underscores violate Go naming standards
- Need clean foundation before advancing to comprehensive option testing
- Easier to manage migration now than after adding more features

### Phase Order (UPDATED):

1. **✅ Phase 1**: Rename Go Test Fixtures for Clarity - COMPLETED
2. **✅ Phase 2**: Create Missing Integration Tests - COMPLETED
3. **✅ Phase 2.1**: Migrate from Co-location to Mirrored Structure - **COMPLETED!**
4. **🔄 Phase 2.2**: Rename to Go-Conventional Package Names - **IN PROGRESS**
5. **⏳ Phase 2.5**: Comprehensive Option Testing Coverage - **NEXT AFTER 2.2**
6. **⏳ Phase 3+**: Organize, update files, remove from CI, documentation

---

## Phase 2.1: Migrate from Co-location to Mirrored Structure - **✅ COMPLETED!**

### 🎯 CRITICAL: Undo Co-location Strategy - **✅ DONE**

**Problem with co-location approach was SOLVED:**

- ✅ Go directories are now clean (no `.lua` files)
- ✅ Go conventions followed (pure Go files only)
- ✅ Clear separation between fixtures and tests achieved
- ✅ Go directories are clean and professional

**Solution: Mirrored directory structure - ✅ IMPLEMENTED**

### Migration Steps - **✅ ALL COMPLETED**:

- [x] **Create mirrored structure**: Create `tests/integration/fixtures/`
      directory
- [x] **Move co-located spec files**: Move all `*_spec.lua` files from Go
      directories to mirrored locations  
- [x] **Update spec file paths**: Update file paths in spec files to point to Go
      fixtures
- [x] **Rename spec files**: Rename spec files to match simplified Go directory
      names
- [x] **Clean Go directories**: Remove all `.lua` files from Go fixture
      directories
- [x] **Test migration**: Run `task test-plenary` to ensure all tests still pass
- [x] **Update integration test template**: Update template to use mirrored
      paths

### Specific Files Moved - **✅ ALL COMPLETED**:

- [x] `diagnostic_classification/diagnostic_classification_spec.lua` →
      `tests/integration/fixtures/diagnostics_spec.lua`
- [x] `multi_file_package/multi_file_package_spec.lua` →
      `tests/integration/fixtures/multifile_spec.lua`
- [x] `nested_packages/nested_packages_spec.lua` →
      `tests/integration/fixtures/nested_packages_spec.lua`
- [x] `no_tests_package/no_tests_package_spec.lua` →
      `tests/integration/fixtures/notest_spec.lua`
- [x] `output_sanitization/output_sanitization_spec.lua` →
      `tests/integration/fixtures/sanitization_spec.lua`
- [x] `package_naming/package_naming_spec.lua` →
      `tests/integration/fixtures/naming_spec.lua`
- [x] `position_discovery/positions_spec.lua` →
      `tests/integration/fixtures/positions_spec.lua`
- [x] `special_characters/special_characters_spec.lua` →
      `tests/integration/fixtures/specialchars_spec.lua`
- [x] `testify_suites/positions_spec.lua` →
      `tests/integration/fixtures/testify_spec.lua`
- [x] `treesitter_precision/treesitter_precision_spec.lua` →
      `tests/integration/fixtures/precision_spec.lua`

## Phase 2: Create Missing Integration Tests (COMPLETED)

### ✅ Integration Test Coverage - ALL COMPLETE:

- [x] **`diagnostic_classification_spec.lua`**
  - Tests: `internal/diagnostic_classification/`
  - Verifies: Hint vs error message classification
  - Scenarios: t.Log (hints), t.Error (errors), panics (errors)

- [x] **`treesitter_precision_spec.lua`**
  - Tests: `internal/treesitter_precision/`
  - Verifies: Only real t.Run() calls detected, not method calls
  - Scenarios: Real subtests found, dummy.Run() ignored, benchmarks/fuzz
    handling

- [x] **`output_sanitization_spec.lua`**
  - Tests: `internal/output_sanitization/`
  - Verifies: Binary output doesn't break parsing
  - Scenarios: Random bytes to stdout, output cleaning, sanitize_output option

- [x] **`special_characters_spec.lua`**
  - Tests: `internal/special_characters/`
  - Verifies: Test names with special chars work correctly
  - Scenarios: Spaces, brackets, regex chars, nested subtests

- [x] **`package_naming_spec.lua`**
  - Tests: `internal/package_naming/`
  - Verifies: Blackbox vs whitebox package handling
  - Scenarios: \_test package suffix vs same package tests

- [x] **`multi_file_package_spec.lua`**
  - Tests: `internal/multi_file_package/`
  - Verifies: Multiple test files in same package discovered
  - Scenarios: Tests from both files found and executed

- [x] **`no_tests_package_spec.lua`**
  - Tests: `internal/no_tests_package/`
  - Verifies: Graceful handling of packages without tests
  - Scenarios: No errors when scanning, no false positives

- [x] **`nested_packages_spec.lua`**
  - Tests: `internal/nested_packages/`
  - Verifies: Deep directory structure discovery
  - Scenarios: subpackage2/ and subpackage3/ tests found

### ✅ Already Have Integration Tests (but may need updates):

- [x] **`test_state_behaviors_integration_spec.lua`**
  - Currently: `run_test_fail_skip_spec.lua`
  - Tests: `internal/test_state_behaviors/`
  - Status: ✅ Complete

- [x] **`position_discovery_integration_spec.lua`**
  - Currently: Part of `run_test_spec.lua` + `positions_spec.lua`
  - Tests: `internal/position_discovery/`
  - Status: ✅ Mostly complete

- [x] **`testify_integration_spec.lua`**
  - Currently: `testify/positions_spec.lua`
  - Tests: `internal/testify_suites/`
  - Status: ✅ Complete

## Phase 2.2: Rename to Go-Conventional Package Names - **🔄 IN PROGRESS**

### 🎯 CRITICAL: Remove Underscores from Package Names

**Follow Go naming conventions (no underscores):**

### Renaming Steps:

- [x] **diagnostic_classification/** → **diagnostics/** ✅ ALREADY DONE
- [x] **multi_file_package/** → **multifile/** ✅ ALREADY DONE  
- [ ] **no_tests_package/** → **notest/**
  - [ ] Rename directory: `git mv no_tests_package notest`
  - [ ] Update package declaration in Go file
- [ ] **output_sanitization/** → **sanitization/**
  - [ ] Rename directory: `git mv output_sanitization sanitization`
  - [ ] Rename test file:
        `git mv output_sanitization_test.go sanitization_test.go`
  - [ ] Update package declaration in Go file
- [ ] **package_naming/** → **naming/**
  - [ ] Rename directory: `git mv package_naming naming`
  - [ ] **🚨 CRITICAL**: DO NOT change package declarations in Go files
  - [ ] **Preserve testing patterns**:
    - `xtest.go` (package package_naming) - exported functions for testing
    - `whitebox_test.go` (package package_naming) - GoTestFiles (internal
      access)
    - `blackbox_test.go` (package package_naming_test) - XTestGoFiles (external
      API only)
  - [ ] **Verify after rename**: Ensure XTestGoFiles vs GoTestFiles distinction
        still works
- [ ] **position_discovery/** → **positions/**
  - [ ] Rename directory: `git mv position_discovery positions`
  - [ ] Update package declaration in Go file
- [ ] **special_characters/** → **specialchars/**
  - [ ] Rename directory: `git mv special_characters specialchars`
  - [ ] Rename test file:
        `git mv special_characters_test.go specialchars_test.go`
  - [ ] Update package declaration in Go file
- [ ] **test_state_behaviors/** → **behaviors/**
  - [ ] Rename directory: `git mv test_state_behaviors behaviors`
  - [ ] Update package declarations in Go files
- [ ] **testify_suites/** → **testify/**
  - [ ] Rename directory: `git mv testify_suites testify`
  - [ ] Update package declarations in Go files
- [ ] **treesitter_precision/** → **precision/**
  - [ ] Rename directory: `git mv treesitter_precision precision`
  - [ ] Rename test file:
        `git mv treesitter_precision_test.go precision_test.go`
  - [ ] Update package declaration in Go file

### Post-Rename Updates:

- [ ] **Update lookup_spec.lua**: Update all path references to use new
      directory names
- [ ] **Update integration test paths**: Update any hardcoded paths in
      integration tests
- [ ] **Test after each rename**: Run `task test-plenary` after each directory
      rename
- [ ] **Final verification**: Run full test suite to ensure no broken references

## Phase 2.5: Comprehensive Option Testing Coverage - **AFTER FOUNDATION**

**Based on `lua/neotest-golang/options.lua`, ensure integration tests for:**

**Core Runner Options:**

- [ ] `runner = "go"` vs `runner = "gotestsum"` - Test both execution paths
- [ ] `go_test_args` - Test custom arguments (function and table forms)
- [ ] `gotestsum_args` - Test gotestsum-specific arguments
- [ ] `go_list_args` - Test go list customization

**DAP (Debug Adapter Protocol) Options:**

- [ ] `dap_go_opts` - Test DAP integration options
- [ ] `dap_mode = "dap-go"` vs `dap_mode = "manual"` - Test both debug modes
- [ ] `dap_manual_config` - Test manual DAP configuration

**Environment & Execution:**

- [ ] `env` - Test environment variable injection (function and table forms)

**Testify Integration:**

- [ ] `testify_enabled = false` vs `testify_enabled = true` - Test testify
      detection
- [ ] `testify_operand` - Test custom testify suite detection patterns
- [ ] `testify_import_identifier` - Test testify import identification

**Output & Presentation:**

- [x] `sanitize_output = false` vs `sanitize_output = true` - ✅ Covered in
      output_sanitization_spec.lua
- [ ] `colorize_test_output = true` vs `colorize_test_output = false` - Test
      output coloring

**Warnings & Notifications:**

- [ ] `warn_test_name_dupes` - Test duplicate test name warnings (NOTE: cannot
      be tested yet, as implementation has not yet been done - so we can skip
      this one for now)
- [ ] `warn_test_not_executed` - Test unexecuted test warnings
- [ ] `warn_test_results_missing` - Test missing results warnings

**Logging & Development:**

- [ ] `log_level` - Test different logging levels (TRACE, DEBUG, INFO, WARN,
      ERROR)
- [ ] `dev_notifications` - Test development notification system

**Function vs Table Testing:**

- [ ] Test all options that accept functions (`go_test_args`, `gotestsum_args`,
      `go_list_args`, `dap_go_opts`, `dap_manual_config`, `env`)
- [ ] Verify function evaluation happens at right time
- [ ] Test function return value validation

### 🚨 Skip Only When Justified:

Only skip testing an option if:

1. **Testing would be meaningless** (e.g., purely cosmetic log level
   differences)
2. **External dependencies unavailable** in CI (e.g., specific DAP setups)
3. **Option is deprecated** and documented as such

**Document any skipped options with clear reasoning.**

## Phase 3: Organize Integration Test Structure

### Proposed `tests/integration/` structure:

```
integration/
├── adapter_core/
│   ├── diagnostic_classification_spec.lua
│   ├── treesitter_precision_spec.lua
│   ├── output_sanitization_spec.lua
│   └── position_discovery_spec.lua
├── test_execution/
│   ├── test_state_behaviors_spec.lua
│   ├── special_characters_spec.lua
│   └── package_naming_spec.lua
├── package_discovery/
│   ├── multi_file_package_spec.lua
│   ├── nested_packages_spec.lua
│   └── no_tests_package_spec.lua
├── framework_integration/
│   ├── testify_integration_spec.lua
│   ├── gotestsum_integration_spec.lua
│   └── dap_integration_spec.lua
└── run_modes/
    ├── basic_execution_spec.lua
    └── advanced_execution_spec.lua
```

## Phase 4: Update Existing Files

### Files that need path updates after renaming:

- [ ] `tests/go/lookup_spec.lua` - Update paths to renamed directories
- [ ] Any integration tests that reference old paths
- [ ] `tests/go/go.mod` - May need import path updates

## Phase 5: Remove Go Tests from CI

- [ ] Update `.github/workflows/` to only run `task test-plenary`
- [ ] Document that Go tests are fixtures, not CI tests
- [ ] Update README.md with new testing strategy

## Phase 6: Documentation

- [ ] Create `TESTING.md` with coverage matrix
- [ ] Update README.md with testing strategy explanation
- [ ] Document fixture purposes and corresponding integration tests

## Testing Strategy Summary

**What we're building:**

- Go fixtures = test data representing real-world scenarios
- Lua integration tests = actual tests that verify adapter behavior
- 100% coverage where every Go fixture has corresponding Lua tests
- Clear naming that immediately explains fixture purposes

**Why this approach:**

- Cleaner CI (no confusing "expected failures")
- Better test isolation and control
- More realistic testing of adapter edge cases
- Self-documenting test structure

## Commands to Run After Changes

```bash
# Verify all tests still pass
task test-plenary

# Check formatting
task format

# Verify Go fixtures still compile
cd tests/go && go build ./...
```

## Current File Structure Reference

### Current State (After Phase 1 & 2 - Co-located Structure):

```
tests/
├── go/
│   ├── internal/
│   │   ├── diagnostic_classification/     (diagnostic_classification_test.go + _spec.lua) ❌ MIXED
│   │   ├── multi_file_package/            (first_file_test.go, second_file_test.go + _spec.lua) ❌ MIXED
│   │   ├── nested_packages/               (subpackage2/, subpackage3/ + _spec.lua) ❌ MIXED
│   │   ├── no_tests_package/              (notest.go + _spec.lua) ❌ MIXED
│   │   ├── output_sanitization/           (output_sanitization_test.go + _spec.lua) ❌ MIXED
│   │   ├── package_naming/                (blackbox_test.go, whitebox_test.go + _spec.lua) ❌ MIXED
│   │   ├── position_discovery/            (positions_test.go + _spec.lua) ❌ MIXED
│   │   ├── special_characters/            (special_characters_test.go + _spec.lua) ❌ MIXED
│   │   ├── test_state_behaviors/          (mixed/, passing/, skipping/ subdirs)
│   │   ├── testify_suites/                (positions_test.go, othersuite_test.go + _spec.lua) ❌ MIXED
│   │   └── treesitter_precision/          (treesitter_precision_test.go + _spec.lua) ❌ MIXED
│   └── lookup_spec.lua
├── integration/
│   ├── run_test_dap_spec.lua
│   ├── run_test_fail_skip_spec.lua
│   ├── run_test_gotestsum_basic_spec.lua
│   ├── run_test_gotestsum_spec.lua
│   └── run_test_spec.lua
└── helpers/
    └── real_execution.lua
```

### Target State (Mirrored Structure + Go-Conventional Naming):

```
tests/
├── go/
│   └── internal/                          # PURE Go fixtures only
│       ├── diagnostics/                   (diagnostics_test.go ONLY) ✅ CLEAN
│       ├── multifile/                     (first_file_test.go, second_file_test.go ONLY) ✅ CLEAN
│       ├── nested_packages/               (subpackage2/, subpackage3/ ONLY) ✅ CLEAN + KEEP NAME
│       ├── notest/                        (notest.go ONLY) ✅ CLEAN
│       ├── sanitization/                  (sanitization_test.go ONLY) ✅ CLEAN
│       ├── naming/                        (blackbox_test.go, whitebox_test.go, xtest.go ONLY) ✅ CLEAN
│       ├── positions/                     (positions_test.go, add.go ONLY) ✅ CLEAN
│       ├── specialchars/                  (specialchars_test.go, add.go ONLY) ✅ CLEAN
│       ├── behaviors/                     (mixed/, passing/, skipping/ subdirs) ✅ CLEAN
│       ├── testify/                       (positions_test.go, othersuite_test.go ONLY) ✅ CLEAN
│       └── precision/                     (precision_test.go ONLY) ✅ CLEAN
├── integration/
│   ├── fixtures/                          # MIRRORED structure for fixture tests
│   │   ├── diagnostics_spec.lua           # Tests diagnostics fixture
│   │   ├── multifile_spec.lua             # Tests multifile fixture
│   │   ├── nested_packages_spec.lua       # Tests nested_packages fixture
│   │   ├── notest_spec.lua                # Tests notest fixture
│   │   ├── sanitization_spec.lua          # Tests sanitization fixture
│   │   ├── naming_spec.lua                # Tests naming fixture
│   │   ├── positions_spec.lua             # Tests positions fixture
│   │   ├── specialchars_spec.lua          # Tests specialchars fixture
│   │   ├── behaviors_spec.lua             # Tests behaviors fixture
│   │   ├── testify_spec.lua               # Tests testify fixture
│   │   └── precision_spec.lua             # Tests precision fixture
│   ├── run_test_dap_spec.lua              # Existing complex integration tests
│   ├── run_test_fail_skip_spec.lua
│   ├── run_test_gotestsum_basic_spec.lua
│   ├── run_test_gotestsum_spec.lua
│   └── run_test_spec.lua
└── helpers/
    └── real_execution.lua
```

│ └── lookup_spec.lua ├── integration/ │ ├── run_test_dap_spec.lua │ ├──
run_test_fail_skip_spec.lua │ ├── run_test_gotestsum_basic_spec.lua │ ├──
run_test_gotestsum_spec.lua │ └── run_test_spec.lua └── helpers/ └──
real_execution.lua

```

### Migration Summary:

**Phase 2.1**: Migrate from co-location to mirrored structure (clean separation)
**Phase 2.2**: Rename to Go-conventional package names (remove underscores)

**Key Benefits:**
- ✅ **Clean Go directories** - Only `.go` files, following Go conventions
- ✅ **Clear test organization** - All fixture tests in `tests/integration/fixtures/`
- ✅ **1:1 mapping preserved** - `diagnostics/` fixture → `diagnostics_spec.lua` test
- ✅ **Easy navigation** - Mirror structure makes relationships obvious
- ✅ **Go best practices** - No underscores, proper package naming

```
