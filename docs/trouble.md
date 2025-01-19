---
icon: material/bug
---

# Troubleshooting

## Issues with setting up or using the adapter

- Run `:checkhealth neotest-golang` to review common issues.
- Search previous
  [discussions](https://github.com/fredrikaverpil/neotest-golang/discussions)
  and [issues](https://github.com/fredrikaverpil/neotest-golang/issues).
- Enable logging with the [`log_level`](config.md#log_level) option to further
  inspect what's going on under the hood.

If the problem persists and is configuration-related, please open a discussion
[here](https://github.com/fredrikaverpil/neotest-golang/discussions/new?category=configuration).

For bugs and feature requests, feel free to use discussions or file a detailed
issue.

## Warning "Test(s) not associated (not found/executed)"

There are numerous reasons as to why you might be hitting this warning. Let me
briefly explain:

Neotest-golang processes the test JSON execution output and looks for certain
key/value pairs corresponding to each position (folder, file, test) in the
Neotest tree. Output and statuses are collected and then populated onto each
position's data in the tree, but if a position was never populated with any
data, this warning gets hit.

There are many reasons why this can happen:

- Go did not compile and Neotest-golang failed to pick up on it. The intent is
  that neotest-golang should show a compilation error (please file a bug report
  if this happens).
- You are using the default `go_test_args` (or use the `-race` flag), which
  requires CGO but you don't have `gcc` installed. Read more about this in the
  [`go_test_args`](config.md#go_test_args) option description.
- You are on a system which writes non-UTF8 characters to stdout (in which case
  you can look into [`gotestsum` runner](config.md#runner) and/or
  [`sanitize_output`](config.md#sanitize_output)). This has been reported to
  happen in some specific cases:

      - When on Windows:
        [issues/147](https://github.com/fredrikaverpil/neotest-golang/issues/147)
      - When using Ubuntu snaps:
        [discussions/161](https://github.com/fredrikaverpil/neotest-golang/discussions/161)
      - When using the mongodb test-container:
        [discussions/256](https://github.com/fredrikaverpil/neotest-golang/discussions/256)

## Neotest is slowing down Neovim

Neotest, out of the box with default settings, can appear very slow in large
projects (here, I'm referring to
[this kind of large](https://github.com/kubernetes/kubernetes)). There are a few
things you can do to speed up the Neotest appearance and experience in such
cases, by tweaking the Neotest settings.

You can for example limit the AST-parsing (to detect tests) to the currently
opened file, which in my opinion makes Neotest a joy to work with, even in
ginormous projects. Second, you can tweak the concurrency settings, again for
AST-parsing but also for concurrent test execution. Here is a simplistic example
for [lazy.nvim](https://github.com/folke/lazy.nvim) to show what I mean:

```lua
return {
  {
    "nvim-neotest/neotest",
    opts = {
      -- See all config options with :h neotest.Config
      discovery = {
        -- Drastically improve performance in ginormous projects by
        -- only AST-parsing the currently opened buffer.
        enabled = false,
        -- Number of workers to parse files concurrently.
        -- A value of 0 automatically assigns number based on CPU.
        -- Set to 1 if experiencing lag.
        concurrent = 1,
      },
      running = {
        -- Run tests concurrently when an adapter provides multiple commands to run.
        concurrent = true,
      },
      summary = {
        -- Enable/disable animation of icons.
        animated = false,
      },
    },
  },
}
```

See `:h neotest.Config` for more information.

[Here](https://github.com/fredrikaverpil/dotfiles/blob/main/nvim-fredrik/lua/fredrik/plugins/core/neotest.lua)
is my personal Neotest configuration, for inspiration. Please note that I am
configuring Go and the neotest-golang adapter in a separate file
[here](https://github.com/fredrikaverpil/dotfiles/blob/main/nvim-fredrik/lua/fredrik/plugins/lang/go.lua).

## Go test execution and parallelism

You can set the optional `go_test_args` to control the number of test binaries
and number of tests to run in parallel using the `-p` and `-parallel` flags,
respectively. Execute `go help test`, `go help testflag`, `go help build` for
more information on this. There's also an excellent article written by
[@roblaszczak](https://github.com/roblaszczak) posted
[here](https://threedots.tech/post/go-test-parallelism/) that touches on this
subject further.
