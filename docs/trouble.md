---
icon: material/bug
---

# Troubleshooting

## Issues with setting up or using the adapter

You can run `:checkhealth neotest-golang` to review common issues. If you need
configuring neotest-golang help, please open a discussion
[here](https://github.com/fredrikaverpil/neotest-golang/discussions/new?category=configuration).

You can also enable logging with the [`log_level`](config.md#log_level) option
to further inspect what's going on under the hood.

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
