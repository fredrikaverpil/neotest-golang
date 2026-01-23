package main

import (
	"github.com/fredrikaverpil/pocket/pk"
	"github.com/fredrikaverpil/pocket/tasks/github"
	"github.com/fredrikaverpil/pocket/tasks/golang"
	"github.com/fredrikaverpil/pocket/tasks/lua"
	"github.com/fredrikaverpil/pocket/tasks/markdown"
	"github.com/fredrikaverpil/pocket/tasks/neovim"
)

// Config is the Pocket configuration for this project.
// Edit this file to define your tasks and composition.
var Config = &pk.Config{
	Auto: pk.Serial(
		pk.Parallel(
			markdown.Tasks(),
			lua.Tasks(),
			github.Tasks(),
		),
		pk.WithOptions(
			golang.Tasks(),
			pk.WithDetect(golang.Detect()),
			pk.WithExcludeTask(golang.Test, "tests/go", "tests/features"),
			pk.WithExcludeTask(golang.Lint, "tests/go", "tests/features"),
		),
		// Run plenary tests with both stable and nightly Neovim
		// NOTE: Must be Serial, not Parallel - they share .tests/all/site/ directory
		pk.Serial(
			neovim.Test(neovim.WithVersion(neovim.Stable)),
			neovim.Test(neovim.WithVersion(neovim.Nightly)),
		),
	),
}
