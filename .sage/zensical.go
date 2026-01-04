package main

import (
	"context"
	"os"

	"go.einride.tech/sage/sg"
	"go.einride.tech/sage/tools/sguv"
)

// ZensicalSync installs documentation dependencies using uv.
func ZensicalSync(ctx context.Context) error {
	cmd := sguv.Command(ctx, "sync")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Dir = sg.FromGitRoot(".")
	return cmd.Run()
}

// ZensicalBuild builds the documentation using uv and zensical.
func ZensicalBuild(ctx context.Context) error {
	cmd := sguv.Command(ctx, "run", "zensical", "build")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Dir = sg.FromGitRoot(".")
	return cmd.Run()
}

// ZensicalServe serves the documentation locally using uv and zensical.
func ZensicalServe(ctx context.Context) error {
	cmd := sguv.Command(ctx, "run", "zensical", "serve")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Dir = sg.FromGitRoot(".")
	return cmd.Run()
}
