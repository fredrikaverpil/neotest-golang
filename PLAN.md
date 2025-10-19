# Implementation Plan: Flat Testify Support

## User Preferences

Based on your answers to clarifying questions:

- **Suite Function Visibility**: Hide/remove suite functions entirely (e.g., `TestExampleTestSuite`)
- **ID Format**: Use slash separator → `path::SuiteName/TestName`
- **Nearest Test Infrastructure**: Yes, add testing infrastructure
- **Cross-File Methods**: Simplify - only show methods from current file

## Chosen Approach

**Flat Structure** - Remove namespace nodes and prefix testify test IDs with suite names.

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
  - [x] Ensure replacements map uses: `{"foo_test.TestAlfaSuite": "Test_TestSuite"}`
  - [x] Update methods map to use package-qualified receiver names

- [x] **Update `tree_modification.lua` to use new lookup format**
  - [x] Adjust `M.create_testify_hierarchy` to work with package-qualified keys
  - [x] Match receiver type by both suite function name AND package

- [x] **Add tests for issue #482**
  - [x] Create test fixtures: two packages with same suite struct name
  - [x] Verify methods don't leak between suites
  - [x] Test in `spec/integration/testifysuites_issue482_spec.lua`

**Commit:** `067ba45` - feat(testify): use package-qualified receiver keys to prevent suite collisions

### Phase 2: Implement Flat Tree Structure

- [ ] **Refactor `tree_modification.lua:M.create_testify_hierarchy`**
  - [ ] Remove namespace node creation logic
  - [ ] Remove suite functions from tree (don't show them)
  - [ ] Rename testify method IDs: `path::SuiteName/TestName` format
  - [ ] Keep subtests nested under methods: `path::SuiteName/TestName/SubtestName`
  - [ ] Keep regular tests unchanged
  - [ ] Remove all gap logic code (no longer needed)
  - [ ] Remove cross-file method support (synthetic nodes)

- [ ] **Update subtests handling**
  - [ ] Ensure subtests maintain proper nesting under methods
  - [ ] Update subtest ID format to match new parent format

### Phase 3: Update Runspec Builders

- [ ] **Update `runspec/test.lua` (or relevant builder)**
  - [ ] Parse new ID format: extract suite and method names
  - [ ] Generate correct `-run` flag: `SuiteName/TestMethodName`
  - [ ] Handle subtests: `SuiteName/TestMethodName/SubtestName`
  - [ ] Ensure regular tests continue to work

- [ ] **Update other runspec builders if needed**
  - [ ] Check `runspec/file.lua` - should work without changes
  - [ ] Check `runspec/dir.lua` - should work without changes
  - [ ] Check `runspec/namespace.lua` - may need removal or updates

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

### Phase 5: Update Existing Tests

- [ ] **Update `spec/integration/testifysuites_*_spec.lua`**
  - [ ] Update expected tree structure (no namespaces)
  - [ ] Update expected test IDs (new format with slash)
  - [ ] Verify all testify integration tests pass

- [ ] **Update unit tests if applicable**
  - [ ] Check `spec/unit/*` for testify-related tests
  - [ ] Update expectations for new tree structure

- [ ] **Update test fixtures if needed**
  - [ ] Ensure `tests/features/internal/testifysuites/*` cover edge cases

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

| Risk | Mitigation |
|------|------------|
| Breaking existing testify users | Clear migration notes, version bump |
| Runspec parsing edge cases | Comprehensive tests for ID parsing |
| Subtest nesting issues | Dedicated subtest integration tests |
| "Nearest test" still broken | Extensive cursor position tests |

## Success Criteria

- [x] Issue #482 fixed - no test leaking between packages
- [ ] "Run nearest test" works correctly for all cursor positions
- [ ] All existing tests updated and passing
- [ ] New "nearest test" infrastructure working
- [ ] Documentation updated
- [ ] Code simplified (less complexity than gap logic)

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
