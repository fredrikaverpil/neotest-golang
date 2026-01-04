package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
)

// PlenaryTest runs the full Neovim plenary test suite.
func PlenaryTest(ctx context.Context) error {
	cmd := exec.CommandContext(
		ctx,
		"nvim",
		"--headless",
		"--noplugin",
		"-i", "NONE",
		"-u", "spec/bootstrap.lua",
		"-c", "PlenaryBustedDirectory spec/ { minimal_init = 'spec/minimal_init.lua', timeout = 500000 }",
	)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// PlenaryTestFile runs a single Neovim plenary test file.
// Usage: make plenary-test-file test_path=path/to/test_spec.lua
func PlenaryTestFile(ctx context.Context, testPath string) error {
	if testPath == "" {
		return fmt.Errorf("test path argument is required")
	}

	cmd := exec.CommandContext(
		ctx,
		"nvim",
		"--headless",
		"--noplugin",
		"-i",
		"NONE",
		"-u",
		"spec/bootstrap.lua",
		"-c",
		fmt.Sprintf(
			"lua require('plenary.test_harness').test_directory_command('%s { minimal_init = \"spec/minimal_init.lua\", timeout = 500000 }')",
			testPath,
		),
	)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
