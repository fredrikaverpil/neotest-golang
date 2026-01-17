package main

import (
	"context"

	"github.com/fredrikaverpil/pocket"
	"github.com/fredrikaverpil/pocket/tasks/github"
	"github.com/fredrikaverpil/pocket/tasks/golang"
	"github.com/fredrikaverpil/pocket/tasks/lua"
	"github.com/fredrikaverpil/pocket/tools/nvim"
	"github.com/fredrikaverpil/pocket/tools/tsqueryls"
)

// autoRun defines the tasks that run on ./pok with no arguments.
var autoRun = pocket.Serial(
	// Lua formatting
	pocket.RunIn(lua.Tasks(), pocket.Detect(lua.Detect())),

	// Go workflow for test code
	pocket.RunIn(golang.Tasks(),
		pocket.Detect(golang.Detect()),
		pocket.Skip(golang.Test, "tests/go", "tests/features"),
	),

	// Tree-sitter query formatting
	QueryFormat,

	// Plenary tests
	PlenaryTest,
)

// matrixConfig configures GitHub Actions matrix generation.
var matrixConfig = github.MatrixConfig{
	DefaultPlatforms: []string{"ubuntu-latest"},
	ExcludeTasks:     []string{"github-workflows", "plenary-test"},
}

// Config is the pocket configuration for this project.
var Config = pocket.Config{
	AutoRun: autoRun,
	ManualRun: []pocket.Runnable{
		github.Workflows,
		github.MatrixTask(autoRun, matrixConfig),
	},
	Shim: &pocket.ShimConfig{
		Posix: true,
	},
}

// QueryFormat formats tree-sitter query files using ts_query_ls.
var QueryFormat = pocket.Task("query-format", "format tree-sitter query files", pocket.Serial(
	tsqueryls.Install,
	queryFormat(),
))

func queryFormat() pocket.Runnable {
	return pocket.Do(func(ctx context.Context) error {
		queryDirs := []string{
			"lua/neotest-golang/queries",
			"lua/neotest-golang/features/testify/queries",
		}
		for _, dir := range queryDirs {
			absDir := pocket.FromGitRoot(dir)
			if err := pocket.Exec(ctx, tsqueryls.Name, "format", absDir); err != nil {
				return err
			}
		}
		return nil
	})
}

// PlenaryTestOptions configures the plenary-test task.
type PlenaryTestOptions struct {
	File string `arg:"file" usage:"run a single test file"`
}

// PlenaryTest runs tests with Neovim and plenary.
var PlenaryTest = pocket.Task("plenary-test", "run tests with Neovim and plenary", pocket.Serial(
	nvim.Install,
	plenaryTest(),
), pocket.Opts(PlenaryTestOptions{}))

func plenaryTest() pocket.Runnable {
	return pocket.Do(func(ctx context.Context) error {
		opts := pocket.Options[PlenaryTestOptions](ctx)

		if opts.File != "" {
			// Run single test file
			return pocket.Exec(
				ctx,
				nvim.Name,
				"--headless",
				"--noplugin",
				"-i",
				"NONE",
				"-u",
				"spec/bootstrap.lua",
				"-c",
				"lua require('plenary.test_harness').test_directory_command('"+opts.File+" { minimal_init = \"spec/minimal_init.lua\", timeout = 500000 }')",
			)
		}

		// Run all tests
		return pocket.Exec(ctx, nvim.Name,
			"--headless", "--noplugin", "-i", "NONE",
			"-u", "spec/bootstrap.lua",
			"-c", "PlenaryBustedDirectory spec/ { minimal_init = 'spec/minimal_init.lua', timeout = 500000 }",
		)
	})
}
