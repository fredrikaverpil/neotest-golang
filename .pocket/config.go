package main

import (
	"github.com/fredrikaverpil/pocket/pk"
	"github.com/fredrikaverpil/pocket/tasks/github"
	"github.com/fredrikaverpil/pocket/tasks/golang"
	"github.com/fredrikaverpil/pocket/tasks/lua"
	"github.com/fredrikaverpil/pocket/tasks/markdown"
	"github.com/fredrikaverpil/pocket/tasks/neovim"
	"github.com/fredrikaverpil/pocket/tasks/treesitter"
	"github.com/fredrikaverpil/pocket/tools/gotestsum"
)

// Config is the Pocket configuration for this project.
// Edit this file to define your tasks and composition.
var Config = &pk.Config{
	Auto: pk.Serial(
		pk.Parallel(
			markdown.Tasks(),
			lua.Tasks(),

			// GitHub workflows, including matrix-based task execution
			pk.WithOptions(
				github.Tasks(),
				github.WithSkipPocket(), // skip the simple workflow variant
				github.WithMatrixWorkflow(github.MatrixConfig{
					DefaultPlatforms: []string{"ubuntu-latest"},
					TaskOverrides: map[string]github.TaskOverride{
						"nvim-test-nightly": {Platforms: []string{"ubuntu-latest", "macos-latest", "windows-latest"}},
						"nvim-test-stable":  {Platforms: []string{"ubuntu-latest", "macos-latest", "windows-latest"}},
					},
				}),
			),
		),
		pk.WithOptions(
			golang.Tasks(),
			pk.WithDetect(golang.Detect()),
			pk.WithExcludeTask(golang.Test, "tests/go", "tests/features"),
			pk.WithExcludeTask(golang.Lint, "tests/go", "tests/features"),
		),

		pk.WithOptions(
			treesitter.Tasks(),
			treesitter.WithParser("go"),
		),

		// Run plenary tests with both stable and nightly Neovim
		// NOTE: Must be Serial, not Parallel - they share .tests/all/site/ directory
		pk.Serial(
			gotestsum.Install, // Required for streaming test results in integration tests
			neovim.PlenaryTest(neovim.WithPlenaryNvimVersion(neovim.Stable)),
			neovim.PlenaryTest(neovim.WithPlenaryNvimVersion(neovim.Nightly)),
		),
	),
}
