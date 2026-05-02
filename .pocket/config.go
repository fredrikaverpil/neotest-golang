package main

import (
	"github.com/fredrikaverpil/pocket/pk"
	"github.com/fredrikaverpil/pocket/tasks/docs"
	"github.com/fredrikaverpil/pocket/tasks/github"
	"github.com/fredrikaverpil/pocket/tasks/golang"
	"github.com/fredrikaverpil/pocket/tasks/lua"
	"github.com/fredrikaverpil/pocket/tasks/markdown"
	"github.com/fredrikaverpil/pocket/tasks/treesitter"
)

// Config is the Pocket configuration for this project.
// Edit this file to define your tasks and composition.
var Config = &pk.Config{
	Auto: pk.Serial(
		pk.Parallel(
			markdown.Tasks(),
			lua.Tasks(),
			docs.Tasks(),
		),

		pk.WithOptions(
			golang.Tasks(),
			pk.WithDetect(golang.Detect()),
			pk.WithSkipTask(golang.Test, "tests/go", "tests/features"),
			pk.WithSkipTask(golang.Lint, "tests/go", "tests/features"),
		),

		pk.WithOptions(
			treesitter.Tasks(),
			pk.WithFlags(treesitter.QueryFormatFlags{Parsers: "go"}),
			pk.WithFlags(treesitter.QueryLintFlags{Parsers: "go"}),
		),

		pk.Parallel(
			PlenaryTestStable,
			PlenaryTestNightly,
		),

		// GitHub workflows, including matrix-based task execution
		pk.WithOptions(
			github.Tasks(),
			pk.WithFlags(github.WorkflowFlags{
				PerPocketTaskJob: new(true),
				Platforms:        []github.Platform{github.Ubuntu},
				PerPocketTaskJobOptions: map[string]github.PerPocketTaskJobOption{
					PlenaryTestNightly.Name: {Platforms: github.AllPlatforms()},
					PlenaryTestStable.Name:  {Platforms: github.AllPlatforms()},
				},
			}),
		),
	),
}
