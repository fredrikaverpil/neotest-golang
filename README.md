# neotest-golang

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/fredrikaverpil/neotest-golang)

Reliable Neotest adapter for running Go tests in Neovim.

![neotest-golang](https://github.com/fredrikaverpil/neotest-golang/assets/994357/afb6e936-b355-4d7b-ab73-65c21ee66ae7)

## 🌱 v1 → v2 migration guide

- If using nvim-treesitter, switch to its `main` branch and run `:TSUpdate go`.
- For context, see the
  [updated installation docs](https://fredrikaverpil.github.io/neotest-golang/install/).

## Features

- Supports all [Neotest usage](https://github.com/nvim-neotest/neotest#usage).
- Supports table tests and nested test functions (based on treesitter AST
  parsing).
- DAP support. Either with
  [leoluz/nvim-dap-go](https://github.com/leoluz/nvim-dap-go) integration or
  custom configuration for debugging of tests using
  [delve](https://github.com/go-delve/delve).
- Monorepo support (detect, run and debug tests in sub-projects).
- Streaming results.
- Inline diagnostics.
- Custom `go test` argument support.
- Environment variables support.
- Works great with
  [andythigpen/nvim-coverage](https://github.com/andythigpen/nvim-coverage) for
  displaying coverage in the sign column.
- Supports [testify](https://github.com/stretchr/testify) suites
  ([disabled](https://fredrikaverpil.github.io/neotest-golang/config/#testify_enabled)
  by default).
- Option to sanitize test output from non-UTF8 characters.

...and more!

______________________________________________________________________

Documentation is available at
[https://fredrikaverpil.github.io/neotest-golang](https://fredrikaverpil.github.io/neotest-golang)
