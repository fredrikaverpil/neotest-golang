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

!!! warning "Tests timing out"

    Nvim-nio will hit a hard-coded 2000 millisecond timeout if you are running the
    entire test suite. I have mitigated this in the bootstraping script and also
    opened an issue about that in
    [nvim-neotest/nvim-nio#30](https://github.com/nvim-neotest/nvim-nio/issues/30).

## Test execution flow

When you run `task test` (or `task test-plenary`), the following sequence
occurs:

- Neovim launches headlessly with the command:
  ```sh
  nvim --headless --noplugin -i NONE -u tests/bootstrap.lua -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua', timeout = 500000 }"
  ```
- Bootstrap script runs first (`tests/bootstrap.lua`): - Resets Neovim's runtime
  path to a clean state - Downloads and installs required plugins (e.g.
  plenary.nvim, neotest, nvim-nio, nvim-treesitter) - Configures the test
  environment with proper packpath - Installs the Go treesitter parser -
  Initializes neotest with the golang adapter - Ensures PlenaryBustedDirectory
  command is available
- PlenaryBustedDirectory executes (via the `-c` flag): - Discovers all
  `*_spec.lua` files in the `tests/` directory - For each test file, creates a
  fresh Neovim instance using the minimal init - Some integration tests use
  `tests/helpers/integration.lua` to run actual Go tests
- Minimal init runs per test (`tests/minimal_init.lua`): - Resets runtime path
  to clean state for each test - Sets basic Neovim options (no swapfile, correct
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

### Best practices

When writing tests...

- Use the integration test helper, so that the lua test can execute a Go test we
  can assert on the test results.
- Follow the Arrange, Act, Assert (AAA) pattern.
- Assert the wanted test results (`want`) from the gotten test results (`got`)
  wrapped in `vim.inspect` for easier debugging.

??? note "Example test"

    ```lua
    local _ = require("plenary")
    local options = require("neotest-golang.options")

    -- Load integration helpers
    local integration_path = vim.uv.cwd() .. "/tests/helpers/integration.lua"
    local integration = dofile(integration_path)

    -- Load assertion helpers
    local assert_helpers = dofile(vim.uv.cwd() .. "/tests/helpers/assert.lua")

    describe("Integration: fail/skip paths", function()
      it("file reports failed status when containing failing tests", function()
        -- ===== ARRANGE =====
        ---@type NeotestGolangOptions
        local test_options = { runner = "gotestsum", warn_test_results_missing = false }
        options.set(test_options)

        local test_filepath = vim.uv.cwd()
          .. "/tests/go/internal/teststates/mixed/fail_skip_test.go"
        test_filepath = integration.normalize_path(test_filepath)

        -- ===== ACT =====
        ---@type AdapterExecutionResult
        local got = integration.execute_adapter_direct(test_filepath)

        -- Expected complete adapter execution result
        ---@type AdapterExecutionResult
        local want = {
          results = {
            -- Directory-level result (created by file aggregation)
            [vim.fs.dirname(test_filepath)] = {
              status = "passed",
              errors = {},
            },
            -- File-level result
            [test_filepath] = {
              status = "failed",
              errors = {},
            },
            -- Individual test results (only the ones that actually appear)
            [test_filepath .. "::TestPassing"] = {
              status = "passed",
              errors = {},
            },
            [test_filepath .. "::TestFailing"] = {
              status = "failed",
              errors = {
                {
                  message = "this test intentionally fails",
                  line = 13,
                  severity = 4,
                },
              },
            },
            [test_filepath .. "::TestSkipped"] = {
              status = "skipped",
              errors = {
                {
                  message = "this test is intentionally skipped",
                  line = 18,
                  severity = 4,
                },
              },
            },
            [test_filepath .. "::TestWithFailingSubtest"] = {
              status = "failed",
              errors = {},
            },
            [test_filepath .. "::TestWithSkippedSubtest"] = {
              status = "passed",
              errors = {},
            },
            -- Subtest results
            [test_filepath .. '::TestWithFailingSubtest::"SubtestPassing"'] = {
              status = "passed",
              errors = {},
            },
            [test_filepath .. '::TestWithFailingSubtest::"SubtestFailing"'] = {
              status = "failed",
              errors = {
                {
                  message = "this subtest intentionally fails",
                  line = 28,
                  severity = 4,
                },
              },
            },
            [test_filepath .. '::TestWithSkippedSubtest::"SubtestPassing"'] = {
              status = "passed",
              errors = {},
            },
            [test_filepath .. '::TestWithSkippedSubtest::"SubtestSkipped"'] = {
              status = "skipped",
              errors = {
                {
                  message = "this subtest is intentionally skipped",
                  line = 39,
                  severity = 4,
                },
              },
            },
          },
          run_spec = {
            context = {
              pos_id = test_filepath,
            },
          },
          strategy_result = {
            code = 1,
          },
        }

        -- ===== ASSERT =====

        -- Copy dynamic run_spec fields
        want.run_spec.command = got.run_spec.command
        want.run_spec.cwd = got.run_spec.cwd
        want.run_spec.env = got.run_spec.env
        want.run_spec.stream = got.run_spec.stream
        want.run_spec.strategy = got.run_spec.strategy
        want.run_spec.context.golist_data = got.run_spec.context.golist_data
        want.run_spec.context.stop_stream = got.run_spec.context.stop_stream

        -- Copy dynamic strategy_result fields
        want.strategy_result.output = got.strategy_result.output

        -- Copy tree field if present
        want.tree = got.tree

        -- Copy dynamic output paths for all results
        for pos_id, result in pairs(got.results) do
          if want.results[pos_id] then
            -- Copy output path if it exists
            if result.output then
              want.results[pos_id].output = result.output
            end
            -- Copy short field if it exists
            if result.short then
              want.results[pos_id].short = result.short
            end
          end
        end

        assert.are.same(
          vim.inspect(want),
          vim.inspect(got),
          "Complete adapter execution result should match"
        )
      end)
    end)
    ```
