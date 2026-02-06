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

// PlenaryTestStable runs Neovim plenary tests with stable Neovim.
var PlenaryTestStable = &pk.Task{
	Name:  "nvim-test:stable",
	Usage: "run neovim plenary tests (stable)",
	Flags: map[string]pk.FlagDef{
		"version":      {Default: neovim.Stable, Usage: "neovim version"},
		"site-dir":     {Default: ".tests/stable", Usage: "site directory"},
		"bootstrap":    {Default: "spec/bootstrap.lua", Usage: "bootstrap.lua file path"},
		"minimal-init": {Default: "spec/minimal_init.lua", Usage: "minimal_init.lua file path"},
		"test-dir":     {Default: "spec/", Usage: "test directory"},
		"timeout":      {Default: 500000, Usage: "test timeout in ms"},
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
	Flags: map[string]pk.FlagDef{
		"version":      {Default: neovim.Nightly, Usage: "neovim version"},
		"site-dir":     {Default: ".tests/nightly", Usage: "site directory"},
		"bootstrap":    {Default: "spec/bootstrap.lua", Usage: "bootstrap.lua file path"},
		"minimal-init": {Default: "spec/minimal_init.lua", Usage: "minimal_init.lua file path"},
		"test-dir":     {Default: "spec/", Usage: "test directory"},
		"timeout":      {Default: 500000, Usage: "test timeout in ms"},
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
		version := pk.GetFlag[string](ctx, "version")
		siteDir := pk.GetFlag[string](ctx, "site-dir")
		bootstrap := pk.GetFlag[string](ctx, "bootstrap")
		minInit := pk.GetFlag[string](ctx, "minimal-init")
		testDir := pk.GetFlag[string](ctx, "test-dir")
		timeout := pk.GetFlag[int](ctx, "timeout")

		// Clean and create site directory for isolation.
		absSiteDir := pk.FromGitRoot(siteDir)
		if err := os.RemoveAll(absSiteDir); err != nil {
			return fmt.Errorf("clean site directory: %w", err)
		}
		if err := os.MkdirAll(absSiteDir, 0o755); err != nil {
			return fmt.Errorf("create site directory: %w", err)
		}

		// Set NEOTEST_SITE_DIR so bootstrap.lua uses our isolated directory.
		ctx = pk.ContextWithEnv(ctx, fmt.Sprintf("NEOTEST_SITE_DIR=%s", absSiteDir))

		// Resolve paths from git root so they work regardless of execution directory.
		bootstrapPath := pk.FromGitRoot(bootstrap)
		minimalInitPath := pk.FromGitRoot(minInit)
		testDirPath := pk.FromGitRoot(testDir)

		// Use the specific neovim binary for this version to avoid symlink collisions
		// when running multiple versions in parallel.
		nvimBinary := neovim.BinaryPath(version)

		if pk.Verbose(ctx) {
			pk.Printf(ctx, "  nvim:        %s\n", nvimBinary)
			pk.Printf(ctx, "  bootstrap:   %s\n", bootstrapPath)
			pk.Printf(ctx, "  minimal_init: %s\n", minimalInitPath)
			pk.Printf(ctx, "  test_dir:    %s\n", testDirPath)
			pk.Printf(ctx, "  timeout:     %d\n", timeout)
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
			luaTestDir, luaMinInit, timeout,
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
