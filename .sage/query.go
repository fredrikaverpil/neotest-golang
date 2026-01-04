package main

import (
	"context"
	"os"

	"github.com/fredrikaverpil/sage-ci/tools/sgtsqueryls"
)

// QueryFormat formats tree-sitter query files with ts_query_ls.
func QueryFormat(ctx context.Context) error {
	queries := []string{
		"lua/neotest-golang/queries",
		"lua/neotest-golang/features/testify/queries",
	}

	for _, query := range queries {
		cmd := sgtsqueryls.Command(ctx, "format", query)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			return err
		}
	}

	return nil
}

// QueryLint lints tree-sitter query files with ts_query_ls.
func QueryLint(ctx context.Context) error {
	queries := []string{
		"lua/neotest-golang/queries",
		"lua/neotest-golang/features/testify/queries",
	}

	for _, query := range queries {
		cmd := sgtsqueryls.Command(ctx, "check", query)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			return err
		}
	}

	return nil
}

// QueryLintFix lints and auto-fixes tree-sitter query files.
func QueryLintFix(ctx context.Context) error {
	queries := []string{
		"lua/neotest-golang/queries",
		"lua/neotest-golang/features/testify/queries",
	}

	for _, query := range queries {
		cmd := sgtsqueryls.Command(ctx, "check", query, "--fix")
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			return err
		}
	}

	return nil
}
