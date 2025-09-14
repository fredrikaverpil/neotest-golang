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

Unit tests are meant to test specific lua function capabilities within a small
scope, but sometimes with a large amount of permutations in terms of input
arguments or output.

### Integration tests

Use `spec/helpers/integration.lua` to perform true end-to-end validation by
executing actual Go tests via the neotest-golang adapter:

- **Purpose**: Validates the complete adapter pipeline with real Go projects
- **How it works**: Bypasses `neotest.run.run()` and calls adapter methods
  directly (`discover_positions` → `build_spec` → `results`)
- **What it tests**: Test discovery, command building, execution, and result
  parsing using genuine Go test files
- **Test files**: Real Go tests in `tests/go/` directory are used as fixtures

See the `integration.lua` script for exact details.

This approach provides high confidence that the adapter works correctly with
actual Go projects and test execution scenarios.

The general workflow of adding a new integration test:

1. Add a new `yourtestname_test.go` file in `tests/go/internal/yourpkgname`
2. Add a new lua integration test in
   `spec/integration/yourpkgname[_yourtestname]_spec.lua` which executes the
   `yourtestname_test.go`

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

??? note "Example integration test"

    ```lua
    local _ = require("plenary")
    local options = require("neotest-golang.options")

    -- Load integration helpers
    local integration_path = vim.uv.cwd() .. "/spec/helpers/integration.lua"
    local integration = dofile(integration_path)

    describe("Integration: positions test", function()
      it(
        "file reports test discovery and execution for various position patterns",
        function()
          -- ===== ARRANGE =====
          ---@type NeotestGolangOptions
          local test_options =
            { runner = "gotestsum", warn_test_results_missing = false }
          options.set(test_options)

          local test_filepath = vim.uv.cwd()
            .. "/tests/go/internal/mytestpkg/mytest_test.go"
          test_filepath = integration.normalize_path(test_filepath)

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
                status = "passed",
                errors = {},
              },
              -- Individual test results
              [test_filepath .. "::TestMyTest"] = {
                status = "passed",
                errors = {},
              },
            },
            run_spec = {
              command = {},  -- this will be replaced in the assertion
              context = {
                pos_id = test_filepath,
              },
            },
            strategy_result = {
              code = 1,
            },
            tree = {
              -- this will be replaced in the assertion
              _children = {},
              _nodes = {},
              _key = function()
                return ""
              end,
            },
          }

          -- ===== ACT =====
          ---@type AdapterExecutionResult
          local got = integration.execute_adapter_direct(test_filepath)


          -- ===== ASSERT =====
          want.tree = got.tree
          want.run_spec.cwd = got.run_spec.cwd
          want.run_spec.command = got.run_spec.command
          want.run_spec.env = got.run_spec.env
          want.run_spec.stream = got.run_spec.stream
          want.run_spec.strategy = got.run_spec.strategy
          want.run_spec.context.golist_data = got.run_spec.context.golist_data
          want.run_spec.context.stop_stream = got.run_spec.context.stop_stream
          want.run_spec.context.test_output_json_filepath =
            got.run_spec.context.test_output_json_filepath
          want.strategy_result.output = got.strategy_result.output
          for pos_id, result in pairs(got.results) do
            if want.results[pos_id] then
              -- copy output path if it exists
              if result.output then
                want.results[pos_id].output = result.output
              end
              -- copy short field if it exists
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
        end
      )
    end)
    ```
