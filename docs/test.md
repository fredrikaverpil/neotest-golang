---
icon: material/test-tube
---

# Test setup

Neotest-golang is tested using
[neotest-plenary](https://github.com/nvim-neotest/neotest-plenary) by running
lua unit tests and integration tests.

Tests can be executed either from within Neovim (using neotest-plenary) or in
the terminal. To run all tests from the terminal, simply execute `task test` in
the terminal (requires [Taskfile](https://github.com/go-task/task)).

!!! warning "Tests timing out"

    Nvim-nio will hit a hard-coded 2000 millisecond timeout if you are running the
    entire test suite. I have mitigated this in the bootstraping script and also
    opened an issue about that in
    [nvim-neotest/nvim-nio#30](https://github.com/nvim-neotest/nvim-nio/issues/30).

## Test execution flow

When you run `task test` (or, rather `task test-plenary`), the following
sequence occurs:

- Neovim launches headlessly with the command:
  ```sh
  nvim --headless --noplugin -i NONE -u spec/bootstrap.lua -c "PlenaryBustedDirectory spec/ { minimal_init = 'spec/minimal_init.lua', timeout = 500000 }"
  ```
- Bootstrap script runs first (`spec/bootstrap.lua`): - Resets Neovim's runtime
  path to a clean state - Downloads and installs required plugins (e.g.
  plenary.nvim, neotest, nvim-nio, nvim-treesitter) - Configures the test
  environment with proper packpath - Installs the Go treesitter parser -
  Initializes neotest with the golang adapter - Ensures PlenaryBustedDirectory
  command is available
- PlenaryBustedDirectory executes (via the `-c` flag): - Discovers all
  `*_spec.lua` files in the `spec/` directory - For each test file, creates a
  fresh Neovim instance using the minimal init - Some integration tests use
  `spec/helpers/integration.lua` to run actual Go tests
- Minimal init runs per test (`spec/minimal_init.lua`): - Resets runtime path to
  clean state for each test - Sets basic Neovim options (no swapfile, correct
  packpath) - Provides isolated environment for individual test execution

??? tip "Neovim vs Busted execution"

    The below outlines why BustedPlenary was chosen instead of Busted.

    This setup uses Neovim's `-c` flag to execute commands within Neovim's context,
    rather than Busted's `-l` flag which loads Lua files externally.

    **Strengths of plenary-busted approach:**

    - Tests run within actual Neovim instances, providing authentic plugin behavior
    - Full access to Neovim APIs (vim.*, treesitter, etc.) during testing
    - Each test gets a clean Neovim environment via the minimal init
    - Integration tests can interact with real neotest functionality
    - No need to mock Neovim-specific behavior

    **Weaknesses compared to pure Busted:**

    - Slower execution due to Neovim startup overhead per test
    - More complex setup and bootstrapping process
    - Harder to debug test failures (headless Neovim environment)
    - Potential for Neovim version-specific test behavior
    - More memory and resource intensive

## Writing tests

### Unit tests

Unit tests (in `./spec/unit`) are meant to test specific lua function
capabilities within a small scope, but sometimes with a large amount of
permutations in terms of input arguments or output.

### Integration tests

Integration tests (in `./spec/integration`) performs end-to-end validation by
executing actual Go tests via the neotest-golang adapter.

The general workflow of adding a new integration test:

1. Add a new `yourtestname_test.go` file in `tests/go/internal/yourpkgname`
2. Add a new lua integration test in
   `spec/integration/yourpkgname[_yourtestname]_spec.lua` and from it, execute
   all tests in a dir, a file or specifiy individual test(s):

   ```lua
   local integration = require("spec.helpers.integration")

   -- Run all tests in a directory
   local result = integration.execute_adapter_direct("/path/to/directory")

   -- Run all tests in a file
   local result = integration.execute_adapter_direct("/path/to/file_test.go")

   -- Run a specific test function
   local result = integration.execute_adapter_direct("/path/to/file_test.go::TestFunction")

   -- Run a specific subtest
   local result = integration.execute_adapter_direct("/path/to/file_test.go::TestFunction::\"SubTest\"")

   -- Run a nested subtest
   local result = integration.execute_adapter_direct("/path/to/file_test.go::TestFunction::\"SubTest\"::\"TableTest\"")
   ```

### Best practices

When writing tests...

- Always use `gotestsum` as runner to prevent flaky tests due to failures with
  parsing JSON in stdout. Set any other options which might be required by the
  test.
- Follow the Arrange, Act, Assert (AAA) pattern.
- Assert on the _full_ wanted test results (`want`) from the gotten test results
  (`got`) wrapped in `vim.inspect` for easier debugging. Set
  `want.somefield = got.somefield` if you don't care about asserting explicity
  values.
- Invoke the Go test by calling `execute_adapter_direct` using the
  `Neotest.Position.type` as argument, mimicing what happens when
  `require("neotest").run().run()` executes:
  - Run all tests in dir: `/path/to/folder`
  - Run all tests in file: `/path/to/folder/file_test.go`
  - Run test (and/or sub-tests): `/path/to/folder/file_test.go::TestSomething`
    or `/path/to/folder/file_test.go::TestSomething::"TestSubTest"`:

## Debugging Testify Suite Issues

The testify suite feature in neotest-golang is complex because it requires
transforming the neotest tree to create proper namespace hierarchies for testify
receiver methods. This section documents debugging techniques for
testify-related issues.

### Understanding Testify Architecture

Testify suites use Go receiver methods that need to be converted into neotest
namespace structures:

```go
// Receiver type
type ExampleTestSuite struct {
    suite.Suite
}

// Test methods (discovered by testify queries)
func (suite *ExampleTestSuite) TestExample() { ... }
func (suite *ExampleTestSuite) TestExample2() { ... }

// Suite runner function (discovered by regular Go queries)
func TestExampleTestSuite(t *testing.T) {
    suite.Run(t, new(ExampleTestSuite))
}
```

The expected neotest tree structure should be:

```
- TestExampleTestSuite (namespace)
  ├── TestExample (test)
  ├── TestExample2 (test)
  └── TestSubTest (test)
    └── "subtest" (test)
- TestTrivial (regular test)
```

### Debugging Tree Modification Issues

When testify suites aren't working correctly, the issue is usually in the tree
modification process. Add debug output to key functions:

#### 1. Debug Query Discovery

Add this to `lua/neotest-golang/query.lua` in the `detect_tests` function:

```lua
-- DEBUG: Test if treesitter finds testify methods directly
print("=== DEBUG TESTIFY QUERY DETECTION ===")
if options.get().testify_enabled == true then
  local testify_matches = testify.query.run_query_on_file(file_path, testify.query.test_method_query)
  print("Testify test methods found:")
  for name, matches in pairs(testify_matches) do
    print("  " .. name .. ": " .. #matches .. " matches")
    for i, match in ipairs(matches) do
      print("    " .. i .. ". " .. match.text)
    end
  end

  local namespace_matches = testify.query.run_query_on_file(file_path, testify.query.namespace_query)
  print("Namespace matches found:")
  for name, matches in pairs(namespace_matches) do
    print("  " .. name .. ": " .. #matches .. " matches")
    for i, match in ipairs(matches) do
      print("    " .. i .. ". " .. match.text)
    end
  end
end
print("=======================================")
```

#### 2. Debug Tree Structure

Add this to `lua/neotest-golang/features/testify/tree_modification.lua` in the
`modify_neotest_tree` function:

```lua
-- DEBUG: Check what's in the original tree
print("=== DEBUG TESTIFY TREE MODIFICATION ===")
local positions = {}
for i, pos in tree:iter() do
  table.insert(positions, pos)
end

print("Original tree has " .. #positions .. " positions:")
for i, pos in ipairs(positions) do
  local pos_type = pos.type or "nil"
  local pos_name = pos.name or "nil"
  local pos_id = pos.id or "nil"
  print("  " .. i .. ". " .. pos_type .. " [" .. pos_name .. "] - " .. pos_id)
end

-- DEBUG: Check lookup table
print("Lookup table:")
for file, data in pairs(lookup_table) do
  print("  File: " .. file)
  if data.replacements then
    for receiver, suite in pairs(data.replacements) do
      print("    " .. receiver .. " -> " .. suite)
    end
  end
end
print("=======================================")
```

#### 3. Debug Method-to-Receiver Mapping

For testify suites with duplicate method names (like multiple `TestExample`
methods), add this debug output:

```lua
-- DEBUG: Show method to receiver mapping
print("=== METHOD TO RECEIVER MAPPING ===")
print("Method positions by name:")
for method, positions in pairs(method_positions) do
  print("  " .. method .. ": " .. #positions .. " instances")
  for i, pos in ipairs(positions) do
    print("    " .. i .. ". " .. pos.receiver)
  end
end
print("=====================================")
```

### Common Issues and Solutions

#### Issue: Testify methods not discovered

- **Symptom**: Original tree only shows suite functions, no receiver methods
- **Cause**: Testify queries using wrong capture names or invalid syntax
- **Solution**: Ensure testify queries use `@test.name` and `@test.definition`
  (not `@test_name`)
- **Check**: Enable debug output in query detection to see if methods are found

#### Issue: Methods not properly namespaced

- **Symptom**: Flat test structure instead of namespace hierarchy
- **Cause**: Tree modification not creating proper parent-child relationships
- **Solution**: Check method-to-receiver mapping and tree creation logic
- **Check**: Debug tree structure before/after modification

#### Issue: Duplicate method names causing confusion

- **Symptom**: Some testify methods missing or assigned to wrong suites
- **Cause**: Multiple receivers with same method names (e.g., two `TestExample`
  methods)
- **Solution**: Use position/range information to distinguish duplicate method
  names
- **Check**: Debug method-to-receiver mapping to see if all instances are found

#### Issue: Position IDs incorrect

- **Symptom**: Test execution fails or doesn't match expected IDs
- **Cause**: ID replacement logic not updating position IDs correctly
- **Solution**: Ensure regex replacement updates IDs from `::MethodName` to
  `::SuiteFunction::MethodName`
- **Check**: Compare expected vs actual position IDs in test assertions

### Treesitter Query Compatibility

When upgrading nvim-treesitter (especially from master to main branch):

1. **Capture name format**: Main branch requires dots (`@test.name`) not
   underscores (`@test_name`)
2. **Statement list wrappers**: Some queries need additional
   `(statement_list ...)` wrappers
3. **Query validation**: Test queries individually with
   `testify.query.run_query_on_file`

### Testing Testify Changes

When modifying testify functionality:

1. **Enable testify**: Set `testify_enabled = true` in test options
2. **Use integration tests**: Run
   `spec/integration/testifysuites_positions_spec.lua`
3. **Check Go command**: Verify the generated go test command targets suite
   functions
4. **Validate tree structure**: Ensure namespace hierarchy matches expected test
   position IDs
5. **Test edge cases**: Files with multiple suites, duplicate method names,
   subtests
