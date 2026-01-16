package main

import (
	"context"

	"github.com/fredrikaverpil/pocket"
	"github.com/fredrikaverpil/pocket/tasks/github"
	"github.com/fredrikaverpil/pocket/tasks/golang"
	"github.com/fredrikaverpil/pocket/tasks/lua"
	"github.com/fredrikaverpil/pocket/tasks/python"
	"github.com/fredrikaverpil/pocket/tools/nvim"
	"github.com/fredrikaverpil/pocket/tools/tsqueryls"
)

// Config is the pocket configuration for this project.
var Config = pocket.Config{
	AutoRun: pocket.Serial(
		// Lua formatting
		pocket.Paths(lua.Tasks()).DetectBy(lua.Detect()),

		// Python workflow (format, lint, typecheck, test)
		pocket.Paths(python.Tasks()).DetectBy(python.Detect()),

		// Go workflow for test code
		pocket.Paths(golang.Tasks()).DetectBy(golang.Detect()),

		// Tree-sitter query formatting
		QueryFormat,

		// Plenary tests
		PlenaryTest,
	),
	ManualRun: []pocket.Runnable{
		github.Workflows,
	},
	Shim: &pocket.ShimConfig{
		Posix: true,
	},
}

// QueryFormat formats tree-sitter query files using ts_query_ls.
var QueryFormat = pocket.Func("query-format", "format tree-sitter query files", pocket.Serial(
	tsqueryls.Install,
	queryFormat,
))

func queryFormat(ctx context.Context) error {
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
}

// PlenaryTestOptions configures the plenary-test task.
type PlenaryTestOptions struct {
	File string `arg:"file" usage:"run a single test file"`
}

// PlenaryTest runs tests with Neovim and plenary.
var PlenaryTest = pocket.Func("plenary-test", "run tests with Neovim and plenary", pocket.Serial(
	nvim.Install,
	plenaryTest,
)).With(PlenaryTestOptions{})

func plenaryTest(ctx context.Context) error {
	opts := pocket.Options[PlenaryTestOptions](ctx)

	if opts.File != "" {
		// Run single test file
		return pocket.Exec(ctx, nvim.Name,
			"--headless", "--noplugin", "-i", "NONE",
			"-u", "spec/bootstrap.lua",
			"-c", "lua require('plenary.test_harness').test_directory_command('"+opts.File+" { minimal_init = \"spec/minimal_init.lua\", timeout = 500000 }')",
		)
	}

	// Run all tests
	return pocket.Exec(ctx, nvim.Name,
		"--headless", "--noplugin", "-i", "NONE",
		"-u", "spec/bootstrap.lua",
		"-c", "PlenaryBustedDirectory spec/ { minimal_init = 'spec/minimal_init.lua', timeout = 500000 }",
	)
}
