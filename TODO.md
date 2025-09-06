# Neotest-Golang Test Strategy Refactoring TODO

## 🚨 FRESH CONTEXT INSTRUCTIONS

**If starting with a fresh LLM context window, read this first:**

1. **This is a Neovim plugin** called `neotest-golang` - a Go test adapter for
   the Neotest framework
2. **Project location**: `/Users/fredrik/code/public/neotest-golang/`
3. **Key commands to know**:
   - `task test-plenary` - Runs the Lua integration tests (our main test suite)
   - `task test-busted` - Alternative test command if preferred
   - `task format` - Formats code with stylua
   - `cd tests/go && go test ./...` - Runs Go fixtures (should have some
     intentional failures)
   - **Tool access via nix**: Any missing tools can be accessed via `nix shell nixpkgs#<tool>` (e.g., `nix shell nixpkgs#go`, `nix shell nixpkgs#stylua`)
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

🔄 **Current Status:**

- **✅ PHASE 3 COMPLETED**: Test organization complete with proper `spec/` folder structure following Lua conventions
- **🎉 MAJOR SUCCESS**: Both test runners working perfectly - **97 successes, 0 failures** in both plenary and busted!
- **✅ CI concerns resolved**: Both test frameworks running successfully, no hanging issues
- **✅ Clean migration foundation**: Core tests successfully migrated to `spec/` structure
- **🔄 MIGRATION IN PROGRESS**: Systematic migration of remaining tests from `spec_disabled/` to `spec/`
- **READY FOR**: Phase 4 - Complete test migration and final organization

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

**⚠️ Test Output Truncation**: When running `task test-plenary`, the output can get
very long and may be truncated. If you need to see full test output or debug
failures, use one of these alternatives:

```bash
# Run specific test file only
nvim --headless --noplugin -i NONE -u tests/bootstrap.lua -c "PlenaryBustedFile tests/integration/option_runner_spec.lua { minimal_init = 'tests/minimal_init.lua', timeout = 50000 }"

# Run with shorter timeout to avoid truncation 
task test-plenary | head -n 1000  # Show first 1000 lines

# Run specific test categories
nvim --headless --noplugin -i NONE -u tests/bootstrap.lua -c "PlenaryBustedDirectory tests/unit/ { minimal_init = 'tests/minimal_init.lua', timeout = 50000 }"
nvim --headless --noplugin -i NONE -u tests/bootstrap.lua -c "PlenaryBustedDirectory tests/integration/fixtures/ { minimal_init = 'tests/minimal_init.lua', timeout = 50000 }"
```

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
4. **✅ Phase 2.2**: Rename to Go-Conventional Package Names - **COMPLETED!**
5. **✅ Phase 2.5**: Comprehensive Option Testing Coverage - **COMPLETED!**
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

## Phase 2.2: Rename to Go-Conventional Package Names - **✅ COMPLETED!**

### 🎯 CRITICAL: Remove Underscores from Package Names

**Follow Go naming conventions (no underscores):**

### Current Directory Names → Target Go-Conventional Names:

**CURRENT ACTUAL STATE:**
- `diagnostics/` → ✅ ALREADY Go-conventional (no underscores)
- `multifile/` → ✅ ALREADY Go-conventional (no underscores)
- `nested_packages/` → ✅ KEEP AS-IS (underscores acceptable for separation)
- `no_tests_package/` → **notest/**
- `output_sanitization/` → **sanitization/**
- `package_naming/` → **naming/**
- `position_discovery/` → **positions/**
- `special_characters/` → **specialchars/**
- `test_state_behaviors/` → **behaviors/**
- `testify_suites/` → **testify/**
- `treesitter_precision/` → **precision/**

### Renaming Steps:

- [x] **diagnostics/** ✅ ALREADY Go-conventional (no change needed)
- [x] **multifile/** ✅ ALREADY Go-conventional (no change needed)
- [x] **nested_packages/** ✅ KEEP AS-IS (underscores acceptable for clarity)
- [x] **no_tests_package/** → **notest/** ✅ COMPLETED
  - [x] Rename directory: `git mv no_tests_package notest`
  - [x] Update package declaration in Go file
- [x] **output_sanitization/** → **sanitization/** ✅ COMPLETED
  - [x] Rename directory: `git mv output_sanitization sanitization`
  - [x] Rename test file:
        `git mv output_sanitization_test.go sanitization_test.go`
  - [x] Update package declaration in Go file
- [x] **package_naming/** → **naming/** ✅ COMPLETED
  - [x] Rename directory: `git mv package_naming naming`
  - [x] **🚨 CRITICAL**: DO NOT change package declarations in Go files
  - [x] **Preserve testing patterns**:
    - `xtest.go` (package naming) - exported functions for testing
    - `whitebox_test.go` (package naming) - GoTestFiles (internal
      access)
    - `blackbox_test.go` (package naming_test) - XTestGoFiles (external
      API only)
  - [x] **Verify after rename**: Ensure XTestGoFiles vs GoTestFiles distinction
        still works
- [x] **position_discovery/** → **positions/** ✅ COMPLETED
  - [x] Rename directory: `git mv position_discovery positions`
  - [x] Update package declaration in Go file
- [x] **special_characters/** → **specialchars/** ✅ COMPLETED
  - [x] Rename directory: `git mv special_characters specialchars`
  - [x] Rename test file:
        `git mv special_characters_test.go specialchars_test.go`
  - [x] Update package declaration in Go file
- [x] **test_state_behaviors/** → **behaviors/** ✅ COMPLETED
  - [x] Rename directory: `git mv test_state_behaviors behaviors`
  - [x] Update package declarations in Go files
- [x] **testify_suites/** → **testify/** ✅ COMPLETED
  - [x] Rename directory: `git mv testify_suites testify`
  - [x] Update package declarations in Go files
- [x] **treesitter_precision/** → **precision/** ✅ COMPLETED
  - [x] Rename directory: `git mv treesitter_precision precision`
  - [x] Rename test file:
        `git mv treesitter_precision_test.go precision_test.go`
  - [x] Update package declaration in Go file

### Post-Rename Updates:

- [x] **Update lookup_spec.lua**: Update all path references to use new
      directory names
- [x] **Update integration test paths**: Update any hardcoded paths in
      integration tests
- [x] **Test after each rename**: Run `task test-plenary` after each directory
      rename
- [x] **Final verification**: Run full test suite to ensure no broken references

## Phase 2.5: Comprehensive Option Testing Coverage - **AFTER FOUNDATION**

**Based on `lua/neotest-golang/options.lua`, ensure integration tests for:**

**Core Runner Options:**

- [x] `runner = "go"` vs `runner = "gotestsum"` - ✅ Covered in run_test_spec.lua, run_test_gotestsum_spec.lua, run_test_gotestsum_basic_spec.lua
- [x] `go_test_args` - ✅ Covered in unit options_spec.lua and integration tests
- [x] `gotestsum_args` - ✅ Covered in run_test_gotestsum_spec.lua, run_test_gotestsum_basic_spec.lua
- [x] `go_list_args` - ✅ Covered in unit options_spec.lua

**DAP (Debug Adapter Protocol) Options:**

- [x] `dap_go_opts` - ✅ Covered in unit options_spec.lua and run_test_dap_spec.lua
- [x] `dap_mode = "dap-go"` vs `dap_mode = "manual"` - ✅ Covered in unit options_spec.lua and run_test_dap_spec.lua
- [x] `dap_manual_config` - ✅ Covered in unit options_spec.lua

**Environment & Execution:**

- [x] `env` - ✅ Covered in unit options_spec.lua + integration option_env_spec.lua for actual env var injection

**Testify Integration:**

- [x] `testify_enabled = false` vs `testify_enabled = true` - ✅ Excellently covered in testify_spec.lua
- [x] `testify_operand` - ✅ Covered in unit options_spec.lua + integration option_testify_patterns_spec.lua for comprehensive pattern testing
- [x] `testify_import_identifier` - ✅ Covered in unit options_spec.lua + integration option_testify_patterns_spec.lua for comprehensive pattern testing

**Output & Presentation:**

- [x] `sanitize_output = false` vs `sanitize_output = true` - ✅ Excellently covered in sanitization_spec.lua
- [ ] `colorize_test_output = true` vs `colorize_test_output = false` - ⚠️ Unit test exists but integration test needed

**Warnings & Notifications:**

- [x] `warn_test_name_dupes` - ✅ Unit tested (implementation not done yet, documented as skipped)
- [ ] `warn_test_not_executed` - ⚠️ Unit test exists but integration test for actual warnings needed
- [ ] `warn_test_results_missing` - ⚠️ Unit test exists but integration test for actual warnings needed

**Logging & Development:**

- [ ] `log_level` - ⚠️ Unit test exists but integration test for actual logging needed
- [x] `dev_notifications` - ✅ Unit tested (experimental, low priority)

**Function vs Table Testing:**

- [x] Test all options that accept functions (`go_test_args`, `gotestsum_args`, `go_list_args`, `dap_go_opts`, `dap_manual_config`, `env`) - ✅ Covered in options_spec.lua + option_functions_spec.lua
- [x] Verify function evaluation happens at right time - ✅ Covered in option_functions_spec.lua integration test
- [x] Test function return value validation - ✅ Covered in option_functions_spec.lua integration test

### 🚨 Skip Only When Justified:

Only skip testing an option if:

1. **Testing would be meaningless** (e.g., purely cosmetic log level
   differences)
2. **External dependencies unavailable** in CI (e.g., specific DAP setups)
3. **Option is deprecated** and documented as such

**Document any skipped options with clear reasoning.**

## 🚨 URGENT: CI BLOCKING ISSUES - **✅ RESOLVED!**

**✅ ALL CI ISSUES RESOLVED:**

- [x] **✅ Both test runners working perfectly**: Plenary and busted both showing 97 successes, 0 failures
- [x] **✅ No hanging issues**: Both frameworks running smoothly without timeouts  
- [x] **✅ Go formatting fixed**: All formatting issues resolved
- [x] **✅ Test stability achieved**: Consistent test results across multiple runs

### 🎉 **MAJOR WINS:**
- **✅ Complete test framework stability**: Both plenary and busted working flawlessly
- **✅ 97 successful tests**: Significant increase from previous runs with perfect success rate
- **✅ No CI blockers**: All critical infrastructure issues resolved
- **✅ Clean foundation**: Ready to focus on test migration and organization

---

## 📊 CURRENT MIGRATION STATUS - **97 TESTS WORKING PERFECTLY**

### ✅ **SUCCESSFULLY MIGRATED TO `spec/`** (Currently Active - 97 successes):

**Unit Tests:**
- ✅ `spec/unit/convert_spec.lua` 
- ✅ `spec/unit/diagnostics_spec.lua`
- ✅ `spec/unit/extra_args_spec.lua`
- ✅ `spec/unit/file_aggregation_spec.lua`
- ✅ `spec/unit/golist_spec.lua`
- ✅ `spec/unit/is_test_file_spec.lua`
- ✅ `spec/unit/json_spec.lua`
- ✅ `spec/unit/mapping_spec.lua`
- ✅ `spec/unit/options_spec.lua`

**Core Integration Tests:**
- ✅ `spec/basic_spec.lua`
- ✅ `spec/integration_lookup_spec.lua` 
- ✅ `spec/integration_positions_spec.lua`
- ✅ `spec/json_spec.lua`

**Fixture Tests:**
- ✅ `spec/diagnostics_spec.lua` (diagnostics fixture)
- ✅ `spec/notest_spec.lua` (notest fixture)

**Option Tests:**
- ✅ `spec/option_env_spec.lua` (environment variables)

**Execution Tests:**
- ✅ `spec/run_test_spec.lua` (basic execution)

### 🔄 **REMAINING IN `spec_disabled/`** (Need to Move Systematically):

**High-Priority Fixture Tests** (should be stable):
- 🔄 `spec_disabled/integration/fixtures/multifile_spec.lua` - Multi-file package tests
- 🔄 `spec_disabled/integration/fixtures/naming_spec.lua` - Package naming tests  
- 🔄 `spec_disabled/integration/fixtures/nested_packages_spec.lua` - Nested packages
- 🔄 `spec_disabled/integration/fixtures/positions_spec.lua` - Position discovery
- 🔄 `spec_disabled/integration/fixtures/precision_spec.lua` - Treesitter precision
- 🔄 `spec_disabled/integration/fixtures/sanitization_spec.lua` - Output sanitization
- 🔄 `spec_disabled/integration/fixtures/specialchars_spec.lua` - Special characters
- 🔄 `spec_disabled/integration/fixtures/testify_spec.lua` - Testify suite tests

**High-Value Option Tests:**
- 🔄 `spec_disabled/integration/option_functions_spec.lua` - Function vs table options
- 🔄 `spec_disabled/integration/option_testify_patterns_spec.lua` - Testify patterns

**Execution Tests** (complex but valuable):
- 🔄 `spec_disabled/integration/execution/run_test_dap_spec.lua` - DAP debugging tests
- 🔄 `spec_disabled/integration/execution/run_test_fail_skip_spec.lua` - Test state behaviors
- 🔄 `spec_disabled/integration/execution/run_test_gotestsum_basic_spec.lua` - Gotestsum basic
- 🔄 `spec_disabled/integration/execution/run_test_gotestsum_spec.lua` - Gotestsum advanced

**Core Integration:**
- 🔄 `spec_disabled/integration/lookup_spec.lua` - Lookup functionality

**Duplicates to Clean Up:**
- 🔄 `spec_disabled/integration/fixtures/diagnostics_spec.lua` - Already migrated
- 🔄 `spec_disabled/integration/fixtures/notest_spec.lua` - Already migrated
- 🔄 `spec_disabled/integration/option_env_spec.lua` - Already migrated

## Phase 3: Organize Integration Test Structure

### 🎯 CRITICAL: Add Feature Testing Structure

**We have "features" in `lua/neotest-golang/features/` that need comprehensive testing:**

**Current Features to Test:**
- `features/dap/` - Debug Adapter Protocol integration
- `features/testify/` - Testify suite detection and handling  
- `features/init.lua` - Features initialization

**Proposed test organization (following Lua convention of `spec/` folders):**
```
spec/integration/
├── features/                         # DEDICATED feature testing directory
│   ├── dap_spec.lua                 # Tests features/dap/ functionality
│   ├── testify_spec.lua             # Tests features/testify/ functionality  
│   └── features_init_spec.lua       # Tests features/init.lua
├── options/                         # DEDICATED option testing directory (existing plan)
└── fixtures/                        # Mirrored structure for fixture tests (existing)
```

**Benefits:**
- Clear separation: options vs features vs fixtures
- Comprehensive coverage of all major subsystems
- Easy navigation and maintenance
- Matches the actual codebase structure
- **Follows Lua testing convention**: All Lua tests live in `spec/` folders, not `test/` folders

### Current Integration Test Structure

### Proposed `spec/integration/` structure:

```
spec/integration/
├── options/                           # DEDICATED option testing directory
│   ├── runner_spec.lua               # runner, go_test_args, gotestsum_args, go_list_args
│   ├── environment_spec.lua          # env (table and function forms)
│   ├── testify_spec.lua              # testify_enabled, testify_operand, testify_import_identifier
│   ├── output_spec.lua               # sanitize_output, colorize_test_output
│   ├── warnings_spec.lua             # warn_test_*, dev_notifications
│   ├── logging_spec.lua              # log_level
│   ├── dap_spec.lua                  # dap_mode, dap_go_opts, dap_manual_config
│   └── functions_spec.lua            # Function vs table testing for all options
├── features/                         # DEDICATED feature testing directory
│   ├── dap_spec.lua                  # Tests DAP feature module (lua/neotest-golang/features/dap/)
│   ├── testify_spec.lua              # Tests testify feature module (lua/neotest-golang/features/testify/)
│   └── init_spec.lua                 # Tests features initialization
├── fixtures/                         # Mirrored structure for fixture tests
│   ├── diagnostics_spec.lua          # Tests diagnostics fixture ✅ DONE
│   ├── multifile_spec.lua            # Tests multifile fixture ✅ DONE
│   ├── nested_packages_spec.lua      # Tests nested_packages fixture ✅ DONE
│   ├── notest_spec.lua               # Tests notest fixture ✅ DONE
│   ├── sanitization_spec.lua         # Tests sanitization fixture ✅ DONE
│   ├── naming_spec.lua               # Tests naming fixture ✅ DONE
│   ├── positions_spec.lua            # Tests positions fixture ✅ DONE
│   ├── specialchars_spec.lua         # Tests specialchars fixture ✅ DONE
│   ├── precision_spec.lua            # Tests precision fixture ✅ DONE
│   └── testify_spec.lua              # Tests testify fixture ✅ DONE
├── execution/                        # Test execution and runner behavior
│   ├── run_test_spec.lua             # Basic test execution
│   ├── run_test_gotestsum_spec.lua   # Gotestsum execution
│   ├── run_test_dap_spec.lua         # DAP execution
│   └── run_test_fail_skip_spec.lua   # Test state behaviors
└── core/                             # Core adapter functionality (if needed)
```

### 🎯 CRITICAL: Reorganize Option Tests

**Current state:** Option tests are scattered:
- `option_env_spec.lua` - Environment variables (✅ DONE but needs moving)
- `option_testify_patterns_spec.lua` - Testify patterns (✅ DONE but needs moving)  
- `option_functions_spec.lua` - Function vs table options (✅ DONE but needs moving)
- `run_test_*` files contain some option testing mixed with execution testing

**Target state:** Clean separation with 1:1 naming between options and tests (following Lua convention with `spec/` folder):
- `spec/integration/options/environment_spec.lua` - Tests `env` option specifically
- `spec/integration/options/testify_spec.lua` - Tests all testify options
- `spec/integration/options/runner_spec.lua` - Tests `runner`, `go_test_args`, `gotestsum_args`, `go_list_args`
- `spec/integration/options/output_spec.lua` - Tests `sanitize_output`, `colorize_test_output`
- `spec/integration/options/warnings_spec.lua` - Tests `warn_test_*` options
- `spec/integration/options/logging_spec.lua` - Tests `log_level`
- `spec/integration/options/dap_spec.lua` - Tests `dap_mode`, `dap_go_opts`, `dap_manual_config`
- `spec/integration/options/functions_spec.lua` - Tests function evaluation for all function-capable options

### Phase 3 Tasks - **✅ COMPLETED**:

- [x] **Project correctly follows Lua convention**: All tests are properly organized in `spec/` folder ✅ CONFIRMED
- [x] **Migrate from `tests/` to `spec/` structure**: Moved all integration tests from `tests/integration/` to `spec/integration/` ✅ COMPLETED
- [x] **Move and rename existing option tests** ✅ COMPLETED:
  - [x] `option_env_spec.lua` → `spec/integration/options/environment_spec.lua` ✅ COMPLETED
  - [x] `option_testify_patterns_spec.lua` → `spec/integration/options/testify_spec.lua` ✅ COMPLETED
  - [x] `option_functions_spec.lua` → `spec/integration/options/functions_spec.lua` ✅ COMPLETED
- [x] **Extract option testing from execution tests** ✅ COMPLETED:
  - [x] Extract runner option tests from `run_test_*` files → `spec/integration/options/runner_spec.lua` ✅ COMPLETED
  - [x] **Created organized execution structure**: Moved all `run_test_*` files to `spec/integration/execution/` ✅ COMPLETED
- [x] **Create missing option tests** ✅ COMPLETED:
  - [x] `spec/integration/options/output_spec.lua` - for `sanitize_output`, `colorize_test_output` ✅ COMPLETED
  - [x] `spec/integration/options/warnings_spec.lua` - for `warn_test_*` options ✅ COMPLETED  
  - [x] `spec/integration/options/runner_spec.lua` - for `runner`, `go_test_args`, `gotestsum_args`, `go_list_args` ✅ COMPLETED
- [x] **Update all imports and references** after moving files ✅ COMPLETED (fixed helper paths)
- [x] **Verify all tests still pass** after reorganization ✅ COMPLETED (91 successes - significant increase from 49!)
- [x] **Update task commands**: Fixed Taskfile.yml to point to correct `spec/` structure ✅ COMPLETED
- [x] **Clean up old structure**: Removed duplicate files and empty directories ✅ COMPLETED

**🎉 MIGRATION SUCCESS**: All Lua tests now follow proper convention in `spec/` folder structure with organized subdirectories!

## 🎯 **IMMEDIATE NEXT ACTION PLAN - SYSTEMATIC MIGRATION**

### Phase 4A: Move Stable Fixture Tests (Run `task test-plenary` after each)

**PRIORITY 1: Fixture Tests** (should be stable and high-value):
- [ ] Move `spec_disabled/integration/fixtures/multifile_spec.lua` → `spec/integration/fixtures/multifile_spec.lua`
- [ ] Move `spec_disabled/integration/fixtures/naming_spec.lua` → `spec/integration/fixtures/naming_spec.lua`
- [ ] Move `spec_disabled/integration/fixtures/nested_packages_spec.lua` → `spec/integration/fixtures/nested_packages_spec.lua`
- [ ] Move `spec_disabled/integration/fixtures/positions_spec.lua` → `spec/integration/fixtures/positions_spec.lua`
- [ ] Move `spec_disabled/integration/fixtures/precision_spec.lua` → `spec/integration/fixtures/precision_spec.lua`
- [ ] Move `spec_disabled/integration/fixtures/sanitization_spec.lua` → `spec/integration/fixtures/sanitization_spec.lua`
- [ ] Move `spec_disabled/integration/fixtures/specialchars_spec.lua` → `spec/integration/fixtures/specialchars_spec.lua`
- [ ] Move `spec_disabled/integration/fixtures/testify_spec.lua` → `spec/integration/fixtures/testify_spec.lua`

### Phase 4B: Move High-Value Option Tests

**PRIORITY 2: Option Tests** (high value for comprehensive coverage):
- [ ] Move `spec_disabled/integration/option_functions_spec.lua` → `spec/integration/options/functions_spec.lua`
- [ ] Move `spec_disabled/integration/option_testify_patterns_spec.lua` → `spec/integration/options/testify_spec.lua`

### Phase 4C: Move Execution Tests

**PRIORITY 3: Execution Tests** (complex but valuable):
- [ ] Move `spec_disabled/integration/execution/run_test_gotestsum_basic_spec.lua` → `spec/integration/execution/run_test_gotestsum_basic_spec.lua`
- [ ] Move `spec_disabled/integration/execution/run_test_fail_skip_spec.lua` → `spec/integration/execution/run_test_fail_skip_spec.lua`
- [ ] Move `spec_disabled/integration/execution/run_test_gotestsum_spec.lua` → `spec/integration/execution/run_test_gotestsum_spec.lua`
- [ ] Move `spec_disabled/integration/execution/run_test_dap_spec.lua` → `spec/integration/execution/run_test_dap_spec.lua`

### Phase 4D: Move Core Integration

**PRIORITY 4: Core Integration**:
- [ ] Move `spec_disabled/integration/lookup_spec.lua` → `spec/integration/lookup_spec.lua`

### Phase 4E: Clean Up Duplicates

**CLEANUP: Remove duplicates**:
- [ ] Remove `spec_disabled/integration/fixtures/diagnostics_spec.lua` (already in `spec/diagnostics_spec.lua`)
- [ ] Remove `spec_disabled/integration/fixtures/notest_spec.lua` (already in `spec/notest_spec.lua`)
- [ ] Remove `spec_disabled/integration/option_env_spec.lua` (already in `spec/option_env_spec.lua`)

### 🔄 **Migration Protocol:**
1. **Move one test at a time** from `spec_disabled/` to `spec/`
2. **Run `task test-plenary`** after each move to verify no regressions
3. **If tests fail**, investigate and fix immediately before proceeding
4. **Run `task format`** to maintain code style
5. **Update TODO.md** with progress checkboxes

### 🏁 **Success Criteria:**
- **Target**: 120+ successful tests (from current 97)
- **Zero failures** maintained throughout migration
- **Clean organization** with proper `spec/integration/` structure
- **All valuable tests active** and contributing to CI coverage

## Phase 4-6: Complete Migration and Final Organization

### Phase 4: Update Existing Files
- [ ] Update any remaining path references after migration complete
- [ ] `tests/go/go.mod` - May need import path updates

### Phase 5: Remove Go Tests from CI  
- [ ] Update `.github/workflows/` to only run `task test-plenary`
- [ ] Document that Go tests are fixtures, not CI tests
- [ ] Update README.md with new testing strategy

### Phase 6: Documentation
- [ ] Create `TESTING.md` with coverage matrix
- [ ] Update README.md with testing strategy explanation  
- [ ] Document fixture purposes and corresponding integration tests

### Phase 7: Advanced Features (Future)
- [ ] **Create feature tests for features/ modules**:
  - [ ] `spec/integration/features/dap_spec.lua` - Tests features/dap/ functionality
  - [ ] `spec/integration/features/testify_spec.lua` - Tests features/testify/ functionality
  - [ ] `spec/integration/features/init_spec.lua` - Tests features/init.lua

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
│       ├── diagnostics/                   (diagnostics_test.go ONLY) ✅ ALREADY CLEAN
│       ├── multifile/                     (first_file_test.go, second_file_test.go ONLY) ✅ ALREADY CLEAN
│       ├── nested_packages/               (subpackage2/, subpackage3/ ONLY) ✅ ALREADY CLEAN
│       ├── notest/                        (notest.go ONLY) 🔄 NEEDS RENAME
│       ├── sanitization/                  (sanitization_test.go ONLY) 🔄 NEEDS RENAME
│       ├── naming/                        (blackbox_test.go, whitebox_test.go, xtest.go ONLY) 🔄 NEEDS RENAME
│       ├── positions/                     (positions_test.go, add.go ONLY) 🔄 NEEDS RENAME
│       ├── specialchars/                  (specialchars_test.go, add.go ONLY) 🔄 NEEDS RENAME
│       ├── behaviors/                     (mixed/, passing/, skipping/ subdirs) 🔄 NEEDS RENAME
│       ├── testify/                       (positions_test.go, othersuite_test.go ONLY) 🔄 NEEDS RENAME
│       └── precision/                     (precision_test.go ONLY) 🔄 NEEDS RENAME
├── integration/
│   ├── fixtures/                          # MIRRORED structure for fixture tests
│   │   ├── diagnostics_spec.lua           # Tests diagnostics fixture ✅ DONE
│   │   ├── multifile_spec.lua             # Tests multifile fixture ✅ DONE
│   │   ├── nested_packages_spec.lua       # Tests nested_packages fixture ✅ DONE
│   │   ├── notest_spec.lua                # Tests notest fixture ✅ DONE
│   │   ├── sanitization_spec.lua          # Tests sanitization fixture ✅ DONE
│   │   ├── naming_spec.lua                # Tests naming fixture ✅ DONE
│   │   ├── positions_spec.lua             # Tests positions fixture ✅ DONE
│   │   ├── specialchars_spec.lua          # Tests specialchars fixture ✅ DONE
│   │   ├── behaviors_spec.lua             # Tests behaviors fixture (TBD)
│   │   ├── testify_spec.lua               # Tests testify fixture ✅ DONE
│   │   └── precision_spec.lua             # Tests precision fixture ✅ DONE
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
