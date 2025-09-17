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
