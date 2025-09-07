---
icon: material/test-tube
---

# Test setup

Neotest-golang is tested using
[neotest-plenary](https://github.com/nvim-neotest/neotest-plenary):

- Lua unit tests.
- Integration tests which calls the neotest-golang adapter's detected Go tests.

Tests can be executed either from within Neovim (using neotest-plenary) or in
the terminal. To run all tests from the terminal, simply execute `task test` in
the terminal (requires [Taskfile](https://github.com/go-task/task)).

> [!NOTE]
>
> Nvim-nio will hit a hard-coded 2000 millisecond timeout if you are running the
> entire test suite. I have mitigated this in the bootstraping script and also
> opened an issue about that in
> [nvim-neotest/nvim-nio#30](https://github.com/nvim-neotest/nvim-nio/issues/30).

## Test execution flow

When you run `task test` (or `task test-plenary`), the following sequence
occurs:

1. **Neovim launches headlessly** with the command:

   ```bash
   nvim --headless --noplugin -i NONE -u tests/bootstrap.lua -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua', timeout = 500000 }"
   ```

2. **Bootstrap script runs first** (`tests/bootstrap.lua`):
   - Resets Neovim's runtime path to a clean state
   - Downloads and installs required plugins (e.g. plenary.nvim, neotest,
     nvim-nio, nvim-treesitter)
   - Configures the test environment with proper packpath
   - Installs the Go treesitter parser
   - Initializes neotest with the golang adapter
   - Ensures PlenaryBustedDirectory command is available

3. **PlenaryBustedDirectory executes** (via the `-c` flag):
   - Discovers all `*_spec.lua` files in the `tests/` directory
   - For each test file, creates a fresh Neovim instance using the minimal init
   - Some integration tests use `tests/helpers/integration.lua` to run actual Go
     tests

4. **Minimal init runs per test** (`tests/minimal_init.lua`):
   - Resets runtime path to clean state for each test
   - Sets basic Neovim options (no swapfile, correct packpath)
   - Provides isolated environment for individual test execution

!!! note "Neovim vs Busted execution" This setup uses Neovim's `-c` flag to
execute commands within Neovim's context, rather than Busted's `-l` flag which
loads Lua files externally.

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

## Integration tests

Some integration tests use `tests/helpers/integration.lua` to perform true
end-to-end validation by executing actual Go tests via the neotest-golang
adapter:

- **Purpose**: Validates the complete adapter pipeline with real Go projects
- **How it works**: Bypasses `neotest.run.run()` and calls adapter methods
  directly (`discover_positions` → `build_spec` → `results`)
- **What it tests**: Test discovery, command building, execution, and result
  parsing using genuine Go test files
- **Test files**: Real Go tests in `tests/go/` directory are used as fixtures

The `integration.lua` script performs these steps:

- Discovers test positions: Uses adapter's `discover_positions` method to parse
  Go files with treesitter
- Builds run specification: Calls adapter's `build_spec` to generate proper
  `go test` command with arguments
- Executes actual Go tests: Uses neotest's integrated strategy to run the real
  `go test` command
- Waits for completion: Monitors process execution with timeout handling (60
  seconds)
- Processes results: Calls adapter's `results` method to parse test output into
  neotest format
- Provides assertions: Helper functions to verify test status and output content

This approach provides high confidence that the adapter works correctly with
actual Go projects and test execution scenarios.
