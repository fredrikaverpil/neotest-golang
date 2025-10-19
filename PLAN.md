# Implementation Plan: Flat Testify Support

> **Source:** This plan implements the approach described in
> [TASK.md](./TASK.md)

## Development Workflow

**IMPORTANT**: For each significant step forward:

1. Run `task test` to run all tests or `task test-file -- file_spec.lua` to run
   a single test file.
2. Run `task format` before committing (formatting failures are OK, especially
   git diff at the end)
3. Create a git commit with descriptive message
4. Continue to next step

## User Preferences

Based on your answers to clarifying questions:

- **Suite Function Visibility**: Hide/remove suite functions entirely (e.g.,
  `TestExampleTestSuite`)
- **ID Format**: Use slash separator → `path::SuiteName/TestName`
- **Nearest Test Infrastructure**: Yes, add testing infrastructure
- **Cross-File Methods**: Simplify - only show methods from current file

## Chosen Approach

**Flat Structure** - Remove namespace nodes and prefix testify test IDs with
suite names.

### Rationale:

- ✅ Simpler implementation - straightforward ID renaming
- ✅ No namespace overlap issues - all tests at file level
- ✅ "Nearest test" works correctly - no traversal problems
- ✅ Matches `go test -run` syntax - `SuiteName/TestName`
- ✅ Fixes issue #482 - package-qualified receiver keys in lookup

## Implementation Checklist

### Phase 1: Fix Issue #482 - Package-Qualified Lookup Keys ✅

- [x] **Update `lookup.lua:M.generate_data`**
  - [x] Modify to use package-qualified receiver keys: `package.ReceiverType`
  - [x] Ensure replacements map uses:
        `{"foo_test.TestAlfaSuite": "Test_TestSuite"}`
  - [x] Update methods map to use package-qualified receiver names

- [x] **Update `tree_modification.lua` to use new lookup format**
  - [x] Adjust `M.create_testify_hierarchy` to work with package-qualified keys
  - [x] Match receiver type by both suite function name AND package

- [x] **Add tests for issue #482**
  - [x] Create test fixtures: two packages with same suite struct name
  - [x] Verify methods don't leak between suites
  - [x] Test in `spec/integration/testifysuites_issue482_spec.lua`

**Commit:** `067ba45` - feat(testify): use package-qualified receiver keys to
prevent suite collisions

### Phase 2: Implement Flat Tree Structure ✅

- [x] **Refactor `tree_modification.lua:M.create_testify_hierarchy`**
  - [x] Remove namespace node creation logic
  - [x] Remove suite functions from tree (don't show them)
  - [x] Rename testify method IDs: `path::SuiteName/TestName` format
  - [x] Keep subtests nested under methods: `path::SuiteName/TestName::"SubtestName"`
  - [x] Keep regular tests unchanged
  - [x] Remove all gap logic code (no longer needed)
  - [x] Remove cross-file method support (synthetic nodes)

- [x] **Update subtests handling**
  - [x] Ensure subtests maintain proper nesting under methods
  - [x] Update subtest ID format to match new parent format (uses :: separator)

**Commits:**
- `2e79dbd` - refactor(testify): implement flat tree structure without namespaces
- `c359691` - fix(testify): use :: separator for subtests to match convert.lua expectations
- `cc27dfd` - test(testify): update integration tests for flat tree structure

### Phase 3: Update Runspec Builders ✅

- [x] **Update `runspec/test.lua` (or relevant builder)**
  - [x] Parse new ID format: extract suite and method names (already works via `pos_id_to_go_test_name`)
  - [x] Generate correct `-run` flag: `SuiteName/TestMethodName` (working correctly)
  - [x] Handle subtests: `SuiteName/TestMethodName/SubtestName` (working correctly)
  - [x] Ensure regular tests continue to work (verified)
  - [x] Add unit tests for testify format in `convert_spec.lua`

- [x] **Update other runspec builders if needed**
  - [x] Check `runspec/file.lua` - works without changes (uses regex to find all `func Test*`)
  - [x] Check `runspec/dir.lua` - works without changes (runs all tests in dir)
  - [x] Check `runspec/namespace.lua` - works without changes (uses same conversion function)

**Commit:** `3487184` - test(convert): add unit tests for testify flat structure format

**Key Finding:** The `pos_id_to_go_test_name()` function already handles the flat structure correctly because it preserves the first part after `::`, which now includes `SuiteName/TestName`. No code changes were needed, only verification via unit tests.

### Phase 4: Add "Nearest Test" Testing Infrastructure

- [ ] **Create test helper for "nearest test"**
  - [ ] Create `spec/helpers/nearest.lua` module
  - [ ] Implement function to call Neotest's `nearest` algorithm
  - [ ] Accept: tree, cursor_line → return nearest position

- [ ] **Add integration tests for "nearest test"**
  - [ ] Create `spec/integration/testifysuites_nearest_spec.lua`
  - [ ] Test cursor on testify method → selects correct method
  - [ ] Test cursor on regular test → selects regular test
  - [ ] Test mixed file (testify + regular) with various cursor positions
  - [ ] Test cursor on suite function line (should select what?)
  - [ ] Test cursor between tests

### Phase 5: Update Existing Tests ✅

- [x] **Update `spec/integration/testifysuites_*_spec.lua`**
  - [x] Update expected tree structure (no namespaces)
  - [x] Update expected test IDs (new format with slash)
  - [x] Verify all testify integration tests pass

- [x] **Update unit tests if applicable**
  - [x] Check `spec/unit/*` for testify-related tests (none needed updates)
  - [x] All convert.lua unit tests pass with new format

- [x] **Update test fixtures if needed**
  - [x] Existing fixtures adequate for testing

**Note:** `testifysuites_othersuite_spec.lua` marked as pending (cross-file support removed)

### Phase 6: Documentation and Cleanup

- [ ] **Update documentation**
  - [ ] Update README.md testify section
  - [ ] Document new tree structure vs old
  - [ ] Add migration notes if applicable

- [ ] **Code cleanup**
  - [ ] Remove unused gap logic code
  - [ ] Remove cross-file method support code
  - [ ] Clean up comments referencing old approach
  - [ ] Update type annotations if needed

- [ ] **Create HISTORY entry**
  - [ ] Document this implementation approach
  - [ ] Explain why flat structure was chosen
  - [ ] Reference issue #482 fix

## Testing Strategy

### Unit Tests

- Lookup table generation with package-qualified keys
- ID format transformation logic
- Subtest ID updates

### Integration Tests

- Issue #482: Same suite name in different packages
- "Nearest test" with various cursor positions
- Mixed regular + testify tests in same file
- Testify methods with subtests
- File/dir level test execution

### Manual Testing

- Test in real project with testify suites
- Verify "run nearest test" behavior
- Check tree visualization in Neotest UI
- Verify test execution with various scopes

## Potential Risks & Mitigations

| Risk                            | Mitigation                          |
| ------------------------------- | ----------------------------------- |
| Breaking existing testify users | Clear migration notes, version bump |
| Runspec parsing edge cases      | Comprehensive tests for ID parsing  |
| Subtest nesting issues          | Dedicated subtest integration tests |
| "Nearest test" still broken     | Extensive cursor position tests     |

## Success Criteria

- [x] Issue #482 fixed - no test leaking between packages
- [x] Runspec builders generate correct `-run` flags for testify tests (Phase 3 complete)
- [ ] "Run nearest test" works correctly for all cursor positions (Phase 4 - not yet started)
- [x] All existing tests updated and passing
- [ ] New "nearest test" infrastructure working (Phase 4 - not yet started)
- [ ] Documentation updated (Phase 6 - not yet started)
- [x] Code simplified (less complexity than gap logic) - ~63 lines net reduction!

## Estimated Impact

**Files to modify:**

- `lua/neotest-golang/features/testify/lookup.lua` - Medium changes
- `lua/neotest-golang/features/testify/tree_modification.lua` - Major refactor
- `lua/neotest-golang/runspec/test.lua` - Medium changes
- `spec/integration/testifysuites_*.lua` - Update expectations
- `spec/helpers/nearest.lua` - New file

**Lines of code:**

- ~200 lines removed (gap logic, cross-file, namespace creation)
- ~100 lines added (ID renaming, nearest test helpers, tests)
- Net: Simpler codebase!
