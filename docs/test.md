# Testing Architecture

## Quickstart

### Prerequisites

Before running tests, you need:

1. **Neovim** (stable or nightly)
2. **LuaRocks** package manager
3. **Busted** test framework

#### Installing Prerequisites

**On macOS** (with Homebrew):

```bash
brew install neovim luarocks
luarocks install --local busted
```

**On Ubuntu/Debian**:

```bash
sudo apt-get install neovim luarocks
luarocks install --local busted
```

**With Nix**:

```bash
nix shell nixpkgs#neovim nixpkgs#luarocks
luarocks install --local busted
```

**Note**: The `--local` flag installs busted to `~/.luarocks/` instead of
system-wide.

### Running Tests Locally

The fastest way to run all tests:

```bash
task test
```

This runs all tests using busted within a full Neovim environment.

### Running Tests Interactively in Neovim

1. Install
   [MisanthropicBit/neotest-busted](https://github.com/MisanthropicBit/neotest-busted)
   in your Neovim config:

   ```lua
   {
     "nvim-neotest/neotest",
     dependencies = {
       "MisanthropicBit/neotest-busted",
       -- ... other adapters
     },
     opts = function(_, opts)
       opts.adapters = opts.adapters or {}
       opts.adapters["neotest-busted"] = {
         -- Important: Add paths to find neotest and plenary dependencies
         busted_paths = {
           vim.fn.stdpath("data") .. "/lazy/plenary.nvim/lua/?.lua",
           vim.fn.stdpath("data") .. "/lazy/plenary.nvim/lua/?/init.lua",
           vim.fn.stdpath("data") .. "/lazy/neotest/lua/?.lua",
           vim.fn.stdpath("data") .. "/lazy/neotest/lua/?/init.lua",
           vim.fn.stdpath("data") .. "/lazy/nvim-nio/lua/?.lua",
           vim.fn.stdpath("data") .. "/lazy/nvim-nio/lua/?/init.lua",
         },
       }
     end,
   }
   ```

2. **Open any test file** in Neovim (e.g., `spec/basic_spec.lua`)

3. **Run tests interactively**:
   - `:lua require("neotest").run.run()` - Run nearest test
   - `:lua require("neotest").run.run(vim.fn.expand("%"))` - Run current file
   - `:lua require("neotest").run.run("spec")` - Run all tests
   - Use neotest UI for visual test running and results

**Reference**: See
[Fredrik's personal neotest-busted setup](https://github.com/fredrikaverpil/dotfiles/blob/main/nvim-fredrik/lua/fredrik/plugins/lang/lua.lua)
for a complete configuration example.

### Quick Test Development Workflow

1. **Write a test** in `spec/unit/my_feature_spec.lua`:

   ```lua
   local my_module = require("neotest-golang.my_module")

   describe("my feature", function()
     it("should work correctly", function()
       assert.are.equal("expected", my_module.my_function("input"))
     end)
   end)
   ```

2. **Run the test**: `task test` or use neotest in Neovim

3. **Iterate**: Fix code, run test, repeat

## Overview

This project uses a modern Lua testing stack built on **busted** (test
framework), **plenary.nvim** (Neovim test utilities), **neotest** (test runner),
and **nvim-treesitter** (Go code parsing). The architecture provides both local
development testing and CI automation while maintaining compatibility with the
neotest ecosystem.

## Core Components

### Busted Framework

- **Role**: Core test framework providing `describe()`, `it()`, and assertion
  functions
- **Why**: Standard Lua testing framework with excellent Neovim integration
- **Integration**: Runs within Neovim via `nvim -l` for full API access

### Plenary.nvim

- **Role**: Provides Neovim-specific test utilities and async functions
- **Why**: Essential for testing Neovim plugins that use vim APIs
- **Integration**: Required dependency for any plugin testing in Neovim
  ecosystem

### Neotest

- **Role**: Interactive test runner with UI integration
- **Why**: Allows running individual tests from within Neovim during development
- **Integration**: Uses `neotest-busted` adapter to discover and run our busted
  tests

### Nvim-treesitter

- **Role**: Parses Go code for test discovery and AST operations
- **Why**: Our adapter needs to parse Go test files to find test functions
- **Integration**: Go parser automatically installed and configured for test
  environment

## Test Dependencies

Dependencies are defined in **3 separate locations** because they serve
different purposes and require different formats:

### 1. Local Development (`tests/busted.lua`)

```lua
{
  "nvim-neotest/neotest",
  lazy = true,
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "antoinemadec/FixCursorHold.nvim",
    "nvim-treesitter/nvim-treesitter",
    "MisanthropicBit/neotest-busted",
    "nvim-neotest/neotest-vim-test",
  },
}
```

- **Purpose**: Full Neovim environment with lazy.nvim plugin management
- **Usage**: `task test-busted` command for local development
- **Features**: Automatic plugin installation, TreeSitter setup, real-time
  testing

### 2. CI Environment (`.github/workflows/nvim-busted.yml`)

```bash
git clone --depth 1 https://github.com/nvim-lua/plenary.nvim ~/.local/share/nvim/site/pack/vendor/start/plenary.nvim
git clone --depth 1 https://github.com/nvim-neotest/neotest ~/.local/share/nvim/site/pack/vendor/start/neotest
git clone --depth 1 https://github.com/nvim-neotest/nvim-nio ~/.local/share/nvim/site/pack/vendor/start/nvim-nio
```

- **Purpose**: Minimal, reliable plugin installation for CI
- **Usage**: GitHub Actions automated testing
- **Features**: Fast, cached, isolated environment

### 3. LuaRocks Package (`neotest-golang-scm-1.rockspec`)

```lua
dependencies = {
  "lua >= 5.1",
  "busted >= 2.0.0",
  "nlua"
}
```

- **Purpose**: Package manager compatibility and version constraints
- **Usage**: `luarocks test` and package distribution
- **Features**: Version management, dependency resolution

### Why Not Unified?

These three contexts have fundamentally different requirements:

- **Format differences**: Lazy.nvim specs vs shell commands vs LuaRocks
  constraints
- **Purpose differences**: Development vs CI vs packaging
- **Information differences**: GitHub repos vs system packages vs version ranges

## Test Execution Approaches

### 1. Local Development: `task test-busted`

```bash
nvim -l ./tests/busted.lua spec
```

- **Environment**: Full Neovim with lazy.nvim plugin management
- **Scope**: All tests in `spec/` directory
- **Performance**: Fast iteration with cached dependencies
- **Use case**: Primary development workflow

### 2. CI Testing: GitHub Actions

```bash
luarocks test --local → ./spec/run_tests.sh → PlenaryBusted
```

- **Environment**: Minimal Neovim with manually installed plugins
- **Scope**: All tests via PlenaryBusted execution
- **Performance**: Reliable, isolated, reproducible
- **Use case**: Automated testing on PRs and commits

### 3. Interactive Testing: neotest-busted

```
Neovim neotest UI → neotest-busted adapter → individual test execution
```

- **Environment**: User's existing Neovim configuration
- **Scope**: Individual tests or test files
- **Performance**: Real-time feedback during development
- **Use case**: Interactive debugging and focused testing

## Test Structure

### Directory Organization

```
spec/
├── basic_spec.lua          # Framework validation tests
├── json_spec.lua           # JSON parsing logic tests
└── unit/
    ├── convert_spec.lua    # Position ID conversion tests
    ├── mapping_spec.lua    # Test name mapping tests
    └── options_spec.lua    # Configuration option tests
```

### Test Categories

**Unit Tests** (`spec/unit/`):

- Test individual functions and modules
- No external dependencies or file system access
- Fast execution, suitable for TDD

**Integration Tests** (future: `spec/integration/`):

- Test interactions between components
- May require TreeSitter parsing or file system access
- More comprehensive but slower execution

**Framework Tests** (`spec/basic_spec.lua`):

- Validate that the testing framework itself works
- Simple sanity checks for busted/plenary integration

## Adding New Tests

### For Unit Tests

1. Create test file in `spec/unit/`
2. Follow naming convention: `{module}_spec.lua`
3. Use standard busted syntax: `describe()` and `it()`
4. Test only the module's public API

### For Integration Tests

1. Create test file in `spec/integration/` (when this directory exists)
2. Handle TreeSitter dependencies carefully
3. Use real file fixtures from `tests/go/` when needed
4. Consider CI execution time impact

### Dependency Management

When adding test dependencies:

1. **Add to `tests/busted.lua`** if needed for local development
2. **Update CI workflow** if new plugins needed in CI
3. **Update rockspec** if new LuaRocks packages needed
4. **Document** the change and reasoning

## Troubleshooting

### Common Issues

**Tests fail with "module not found"**:

- Check that dependencies are installed via lazy.nvim in `tests/busted.lua`
- Verify the module path is correct relative to project root

**TreeSitter parser errors**:

- Ensure Go parser is installed:
  `require("nvim-treesitter.install").install("go")`
- Check that TreeSitter configuration in `tests/busted.lua` is correct

**CI tests pass locally but fail in GitHub Actions**:

- Verify CI dependencies match local dependencies
- Check for path or environment differences between local and CI

### Testing the Test Setup

To validate the testing framework:

```bash
# Run basic framework validation
task test

# Should show: "X successes / 0 failures / 0 errors / 0 pending"
```

## Migration History

This testing setup evolved from a Plenary-based system that was experiencing CI
hangs. The migration to busted provided:

- ✅ Reliable CI execution
- ✅ Interactive testing capabilities
- ✅ Standard Lua testing patterns
- ✅ Better integration with neotest ecosystem

The current hybrid approach maintains compatibility while providing multiple
execution paths for different development workflows.
