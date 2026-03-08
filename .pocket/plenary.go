package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"

	"github.com/fredrikaverpil/pocket/pk"
	"github.com/fredrikaverpil/pocket/tools/gotestsum"
	"github.com/fredrikaverpil/pocket/tools/neovim"
	"github.com/fredrikaverpil/pocket/tools/treesitter"
)

// PlenaryFlags holds flags for the plenary test tasks.
type PlenaryFlags struct {
	Version     string `flag:"version"      usage:"neovim version"`
	SiteDir     string `flag:"site-dir"     usage:"site directory"`
	Bootstrap   string `flag:"bootstrap"    usage:"bootstrap.lua file path"`
	MinimalInit string `flag:"minimal-init" usage:"minimal_init.lua file path"`
	TestDir     string `flag:"test-dir"     usage:"test directory"`
	Timeout     int    `flag:"timeout"      usage:"test timeout in ms"`
}

// PlenaryTestStable runs Neovim plenary tests with stable Neovim.
var PlenaryTestStable = &pk.Task{
	Name:  "nvim-test:stable",
	Usage: "run neovim plenary tests (stable)",
	Flags: PlenaryFlags{
		Version:     neovim.Stable,
		SiteDir:     ".tests/stable",
		Bootstrap:   "spec/bootstrap.lua",
		MinimalInit: "spec/minimal_init.lua",
		TestDir:     "spec/",
		Timeout:     500000,
	},
	Body: pk.Serial(
		pk.Parallel(
			neovim.InstallStable,
			gotestsum.Install,
			treesitter.Install,
		),
		runPlenaryTests(),
	),
}

// PlenaryTestNightly runs Neovim plenary tests with nightly Neovim.
var PlenaryTestNightly = &pk.Task{
	Name:  "nvim-test:nightly",
	Usage: "run neovim plenary tests (nightly)",
	Flags: PlenaryFlags{
		Version:     neovim.Nightly,
		SiteDir:     ".tests/nightly",
		Bootstrap:   "spec/bootstrap.lua",
		MinimalInit: "spec/minimal_init.lua",
		TestDir:     "spec/",
		Timeout:     500000,
	},
	Body: pk.Serial(
		pk.Parallel(
			neovim.InstallNightly,
			gotestsum.Install,
			treesitter.Install,
		),
		runPlenaryTests(),
	),
}

func runPlenaryTests() pk.Runnable {
	return pk.Do(func(ctx context.Context) error {
		f := pk.GetFlags[PlenaryFlags](ctx)

		// Clean and create site directory for isolation.
		absSiteDir := pk.FromGitRoot(f.SiteDir)
		if err := os.RemoveAll(absSiteDir); err != nil {
			return fmt.Errorf("clean site directory: %w", err)
		}
		if err := os.MkdirAll(absSiteDir, 0o755); err != nil {
			return fmt.Errorf("create site directory: %w", err)
		}

		// Set NEOTEST_SITE_DIR so bootstrap.lua uses our isolated directory.
		ctx = pk.ContextWithEnv(ctx, fmt.Sprintf("NEOTEST_SITE_DIR=%s", absSiteDir))

		// Resolve paths from git root so they work regardless of execution directory.
		bootstrapPath := pk.FromGitRoot(f.Bootstrap)
		minimalInitPath := pk.FromGitRoot(f.MinimalInit)
		testDirPath := pk.FromGitRoot(f.TestDir)

		// Use the specific neovim binary for this version to avoid symlink collisions
		// when running multiple versions in parallel.
		nvimBinary := neovim.BinaryPath(f.Version)

		if pk.Verbose(ctx) {
			pk.Printf(ctx, "  nvim:        %s\n", nvimBinary)
			pk.Printf(ctx, "  bootstrap:   %s\n", bootstrapPath)
			pk.Printf(ctx, "  minimal_init: %s\n", minimalInitPath)
			pk.Printf(ctx, "  test_dir:    %s\n", testDirPath)
			pk.Printf(ctx, "  timeout:     %d\n", f.Timeout)
			pk.Printf(ctx, "  site_dir:    %s\n", absSiteDir)
		}

		// Convert paths to forward slashes for Lua command.
		// On Windows, filepath.Join produces backslashes which are escape characters
		// in Lua strings, causing parsing errors (e.g., \U, \s are invalid escapes).
		// Forward slashes work fine on all platforms for file paths.
		luaTestDir := filepath.ToSlash(testDirPath)
		luaMinInit := filepath.ToSlash(minimalInitPath)

		plenaryCmd := fmt.Sprintf(
			"PlenaryBustedDirectory %s { minimal_init = '%s', timeout = %d }",
			luaTestDir, luaMinInit, f.Timeout,
		)

		return pk.Exec(ctx, nvimBinary,
			"--headless",
			"--noplugin",
			"-i", "NONE",
			"-u", bootstrapPath,
			"-c", plenaryCmd,
		)
	})
}
