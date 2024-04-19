# neotest-golang

A neotest adapter for running go tests.

🚧 This neotest adapter is under heavy development and not ready to be used in
daily work, although that's what I am doing (dogfooding ftw!).

See the
[kanban board](https://github.com/users/fredrikaverpil/projects/5/views/1) for
development status.

## Background

I've been using Neovim and neotest with
[neotest-go](https://github.com/nvim-neotest/neotest-go) but I have stumbled
upon many problems which seems difficult to solve in the neotest-go codebase.

I have full respect for the time and efforts put in by the developer(s) of
neotest-go. I do not aim in any way to diminish their needs or efforts in
creating the adapter.

However, I would like to see if, by building a Go adapter for neotest from
scractch, whether it will be possible to mitigate the issues I have found with
neotest-go.

## PRs are welcome

Improvement suggestion PRs to this repo are very much welcome, and I encourage
you to begin in the discussions in case the change is not trivial.

## Issues mitigated from the original neotest-go adapter

- Does not produce undesired JSON output thanks to executing with `gotestsum`
  instead of `go test`:
  [neotest-go#52](https://github.com/nvim-neotest/neotest-go/issues/52) Ideally,
  the underlying problem will be fixed in neotest so that `go test` can be used.
- Run "nearest test" doesn't run all tests:
  [neotest-go#83](https://github.com/nvim-neotest/neotest-go/issues/83)
- Supports neotest "run test suite", although a bit buggy right now:
  [neotest-go#89](https://github.com/nvim-neotest/neotest-go/issues/89)

## Installation

```lua
-- lazy.nvim

return {
  {
    "nvim-neotest/neotest",
    ft = { "go" },
    dependencies = {
      {
        "fredrikaverpil/neotest-golang",
        branch = "main",
      },
    },
  },
}
```
