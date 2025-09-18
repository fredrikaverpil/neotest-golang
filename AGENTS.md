# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## Project Overview

This is `neotest-golang`, a Neotest adapter for running Go tests in Neovim. The
project is written primarily in Lua and follows the Neotest adapter interface to
integrate Go testing capabilities into Neovim.

## Core Architecture

The adapter follows the Neotest interface with these key components:

- **`lua/neotest-golang/init.lua`** - Main entry point implementing the Neotest
  adapter interface
- **`lua/neotest-golang/query.lua`** - AST parsing and test discovery using
  treesitter
- **`lua/neotest-golang/runspec/`** - Command builders for different test
  scenarios (dir, file, namespace, test)
- **`lua/neotest-golang/process.lua`** - Test result processing and output
  parsing
- **`lua/neotest-golang/lib/`** - Core utilities and helpers
- **`lua/neotest-golang/features/`** - Advanced features like DAP debugging and
  testify suite support

The adapter handles:

- Test discovery via treesitter AST parsing
- Command generation for various test scopes (directory, file, individual tests)
- Result processing from `go test` and `gotestsum` output
- Integration with DAP for debugging
- Support for testify test suites

## Development Commands

### Testing

- **Run all tests**: `task test` or `task test-plenary`
- **Run tests with clean state**: `task test-clean && task test`
- **Run specific test**: Use nvim with plenary directly

### Linting and Formatting

- **Format Lua code**: `task format` (uses stylua)
- **Lint**: `task lint` (currently a no-op for Lua)
- **Format Go test fixtures**: `task -t tests/go/Taskfile.go.yml format`
- **Lint Go test fixtures**: `task -t tests/go/Taskfile.go.yml lint`

### Documentation

- **Serve docs locally**: Uses mkdocs-material (see pyproject.toml)

## Test Framework

Uses Plenary for Lua testing with neotest-plenary. See `docs/test.md` for
comprehensive testing documentation.

### Test Structure

- Test specs in `spec/` directory
- Unit tests in `spec/unit/` - test specific Lua functions with various input
  permutations
- Integration tests in `spec/integration/` - end-to-end validation executing
  actual Go tests
- Bootstrap configuration in `spec/bootstrap.lua` - sets up clean test
  environment
- Minimal init for testing in `spec/minimal_init.lua` - provides isolated
  environment per test

Test files use the `*_spec.lua` naming convention.

### Test Execution Flow

When running `task test-plenary`, Neovim launches headlessly and:

1. Bootstrap script resets runtime path and installs required plugins
2. PlenaryBustedDirectory discovers and runs all `*_spec.lua` files
3. Each test gets a fresh Neovim instance using minimal init
4. Integration tests use `spec/helpers/integration.lua` to run actual Go tests

### Writing Tests

- **Unit tests**: Test specific Lua function capabilities in small scope
- **Integration tests**: Add Go test files in `tests/go/internal/` and
  corresponding Lua specs
- Use `integration.execute_adapter_direct()` to test different position types
  (dir, file, test)
- Always use `gotestsum` as runner to prevent JSON parsing issues
- Follow Arrange, Act, Assert (AAA) pattern
- Assert on full test results using `vim.inspect` for easier debugging

## Configuration Files

- **`.lazy.lua`** - Local development configuration for lazy.nvim
- **`stylua.toml`** - Code formatting rules for Lua
- **`.golangci.yml`** - Linting configuration for Go test fixtures
- **`Taskfile.yml`** - Main task runner configuration
- **`Taskfile.lua.yml`** - Lua-specific tasks
- **`tests/go/Taskfile.go.yml`** - Go test fixture tasks

## Key Patterns

1. **Position Types**: The adapter handles 4 position types from Neotest:
   - `dir` - Directory of tests
   - `file` - Single test file
   - `namespace` - Group of tests (e.g., testify suites)
   - `test` - Individual test function

2. **Runspec Strategy**: Each position type has its own runspec builder in
   `lua/neotest-golang/runspec/`

3. **Streaming Support**: Recent additions include streaming strategy support
   for live test output

4. **Error Handling**: Comprehensive logging through
   `lua/neotest-golang/logging.lua`

## Dependencies

- **Lua**: uga-rosa/utf8.nvim for UTF-8 handling
- **Go**: Uses `go test` and optionally `gotestsum` for enhanced output
- **Python**: mkdocs-material for documentation (development only)

## File Structure Conventions

- Core adapter logic in `lua/neotest-golang/`
- Features and extensions in `lua/neotest-golang/features/`
- Library utilities in `lua/neotest-golang/lib/`
- Test specifications in `spec/`
- Go test fixtures in `tests/go/`

