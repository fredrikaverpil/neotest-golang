package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"path/filepath"

	"github.com/fredrikaverpil/pocket/pk"
	"github.com/fredrikaverpil/pocket/pk/pcontext"
	"github.com/fredrikaverpil/pocket/tools/gotestsum"
	"github.com/fredrikaverpil/pocket/tools/neovim"
	"github.com/fredrikaverpil/pocket/tools/treesitter"
)

// addCommonFlags adds common flags to a flag set and returns pointers to their values.
func addCommonFlags(fs *flag.FlagSet) (bootstrap, minInit, testDir *string, timeout *int) {
	return fs.String("bootstrap", "spec/bootstrap.lua", "bootstrap.lua file path"),
		fs.String("minimal-init", "spec/minimal_init.lua", "minimal_init.lua file path"),
		fs.String("test-dir", "spec/", "test directory"),
		fs.Int("timeout", 500000, "test timeout in ms")
}

// Stable task flags with stable defaults.
var (
	stableFlags = flag.NewFlagSet(
		"nvim-test:stable",
		flag.ContinueOnError,
	)
	stableVersion = stableFlags.String(
		"version",
		neovim.Stable,
		"neovim version",
	)
	stableSiteDir = stableFlags.String(
		"site-dir",
		".tests/stable",
		"site directory",
	)
	stableBootstrap, stableMinInit, stableTestDir, stableTimeout = addCommonFlags(stableFlags)
)

// Nightly task flags with nightly defaults.
var (
	nightlyFlags = flag.NewFlagSet(
		"nvim-test:nightly",
		flag.ContinueOnError,
	)
	nightlyVersion = nightlyFlags.String(
		"version",
		neovim.Nightly,
		"neovim version",
	)
	nightlySiteDir = nightlyFlags.String(
		"site-dir",
		".tests/nightly",
		"site directory",
	)
	nightlyBootstrap, nightlyMinInit, nightlyTestDir, nightlyTimeout = addCommonFlags(nightlyFlags)
)

// PlenaryTestStable runs Neovim plenary tests with stable Neovim.
var PlenaryTestStable = pk.NewTask("nvim-test:stable", "run neovim plenary tests (stable)", stableFlags,
	pk.Serial(
		pk.Parallel(
			neovim.InstallStable,
			gotestsum.Install,
			treesitter.Install,
		),
		runPlenaryTests(stableVersion, stableSiteDir, stableBootstrap, stableMinInit, stableTestDir, stableTimeout),
	),
)

// PlenaryTestNightly runs Neovim plenary tests with nightly Neovim.
var PlenaryTestNightly = pk.NewTask("nvim-test:nightly", "run neovim plenary tests (nightly)", nightlyFlags,
	pk.Serial(
		pk.Parallel(
			neovim.InstallNightly,
			gotestsum.Install,
			treesitter.Install,
		),
		runPlenaryTests(
			nightlyVersion,
			nightlySiteDir,
			nightlyBootstrap,
			nightlyMinInit,
			nightlyTestDir,
			nightlyTimeout,
		),
	),
)

func runPlenaryTests(version, siteDir, bootstrap, minInit, testDir *string, timeout *int) pk.Runnable {
	return pk.Do(func(ctx context.Context) error {
		// Clean and create site directory for isolation.
		absSiteDir := pk.FromGitRoot(*siteDir)
		if err := os.RemoveAll(absSiteDir); err != nil {
			return fmt.Errorf("clean site directory: %w", err)
		}
		if err := os.MkdirAll(absSiteDir, 0o755); err != nil {
			return fmt.Errorf("create site directory: %w", err)
		}

		// Set NEOTEST_SITE_DIR so bootstrap.lua uses our isolated directory.
		ctx = pcontext.WithEnv(ctx, fmt.Sprintf("NEOTEST_SITE_DIR=%s", absSiteDir))

		// Resolve paths from git root so they work regardless of execution directory.
		bootstrapPath := pk.FromGitRoot(*bootstrap)
		minimalInitPath := pk.FromGitRoot(*minInit)
		testDirPath := pk.FromGitRoot(*testDir)

		// Use the specific neovim binary for this version to avoid symlink collisions
		// when running multiple versions in parallel.
		nvimBinary := neovim.BinaryPath(*version)

		if pcontext.Verbose(ctx) {
			pk.Printf(ctx, "  nvim:        %s\n", nvimBinary)
			pk.Printf(ctx, "  bootstrap:   %s\n", bootstrapPath)
			pk.Printf(ctx, "  minimal_init: %s\n", minimalInitPath)
			pk.Printf(ctx, "  test_dir:    %s\n", testDirPath)
			pk.Printf(ctx, "  timeout:     %d\n", *timeout)
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
			luaTestDir, luaMinInit, *timeout,
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
