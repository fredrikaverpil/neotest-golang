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
	treesitterTool "github.com/fredrikaverpil/pocket/tools/treesitter"
)

// Config is the Pocket configuration for this project.
// Edit this file to define your tasks and composition.
var Config = &pk.Config{
	Auto: pk.Serial(
		pk.Parallel(
			markdown.Tasks(),
			lua.Tasks(),
		),

		pk.WithOptions(
			golang.Tasks(),
			pk.WithDetect(golang.Detect()),
			pk.WithExcludeTask(golang.Test, "tests/go", "tests/features"),
			pk.WithExcludeTask(golang.Lint, "tests/go", "tests/features"),
		),

		pk.WithOptions(
			treesitter.Tasks(),
			pk.WithFlag(treesitter.QueryFormat, "parsers", "go"),
			pk.WithFlag(treesitter.QueryLint, "parsers", "go"),
		),

		// Run plenary tests with both stable and nightly Neovim
		pk.Serial(
			pk.Parallel(
				gotestsum.Install,
				neovim.InstallStable,
				neovim.InstallNightly,
				treesitterTool.Install,
			),
			pk.Parallel(
				neovim.PlenaryTestStable,
				neovim.PlenaryTestNightly,
			),
		),

		// GitHub workflows, including matrix-based task execution
		pk.WithOptions(
			github.Tasks(),
			pk.WithFlag(github.Workflows, "skip-pocket", true),
			pk.WithFlag(github.Workflows, "include-pocket-matrix", true),
			pk.WithContextValue(github.MatrixConfigKey{}, github.MatrixConfig{
				DefaultPlatforms: []string{"ubuntu-latest"},
				TaskOverrides: map[string]github.TaskOverride{
					"nvim-test:nightly": {Platforms: []string{"ubuntu-latest", "macos-latest", "windows-latest"}},
					"nvim-test:stable":  {Platforms: []string{"ubuntu-latest", "macos-latest", "windows-latest"}},
				},
			}),
		),
	),
}
