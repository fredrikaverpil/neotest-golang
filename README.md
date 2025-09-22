# neotest-golang

Reliable Neotest adapter for running Go tests in Neovim.

![neotest-golang](https://github.com/fredrikaverpil/neotest-golang/assets/994357/afb6e936-b355-4d7b-ab73-65c21ee66ae7)

## 🌱 v1 → v2 migration guide

**Breaking changes in v2.0.0** - see the
[migration guide](https://github.com/fredrikaverpil/neotest-golang/releases/tag/v2.0.0)
for full details.

## Features

- Supports all [Neotest usage](https://github.com/nvim-neotest/neotest#usage).
- Supports table tests and nested test functions (based on treesitter AST
  parsing).
- DAP support. Either with
  [leoluz/nvim-dap-go](https://github.com/leoluz/nvim-dap-go) integration or
  custom configuration for debugging of tests using
  [delve](https://github.com/go-delve/delve).
- Monorepo support (detect, run and debug tests in sub-projects).
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

---

Documentation is available at
[https://fredrikaverpil.github.io/neotest-golang](https://fredrikaverpil.github.io/neotest-golang)
