package main

import (
	"context"

	"github.com/fredrikaverpil/sage-ci/config"
	"github.com/fredrikaverpil/sage-ci/targets"
	"go.einride.tech/sage/sg"
)

var cfg = config.Config{
	GoModules: []string{"tests/go", "tests/features"},
	// TODO: should be enabled, but re-formats files
	// LuaModules: []string{"lua", "spec"},

	SkipTargets: config.SkipTargets{
		"GoTest": {"tests/go", "tests/features"},

		// TODO: should be enabled, but requires changes to tests
		"GoLint": {"tests/go", "tests/features"},
	},
}

func main() {
	sg.GenerateMakefiles(
		sg.Makefile{
			Path:          sg.FromGitRoot("Makefile"),
			DefaultTarget: All,
		},
	)
}

// All is the default target. Customize this to run the targets you need.
func All(ctx context.Context) error {
	if err := targets.RunSerial(ctx, cfg); err != nil {
		return err
	}
	if err := targets.RunParallel(ctx, cfg); err != nil {
		return err
	}
	sg.Deps(ctx, QueryFormat, PlenaryTest)
	sg.SerialDeps(ctx, ZensicalBuild)
	sg.Deps(ctx, targets.GitDiffCheckTarget())
	return nil
}

// UpdateSageCi updates the sage-ci dependency and regenerates Makefiles and workflows.
func UpdateSageCi(ctx context.Context) error {
	return targets.UpdateSageCi(ctx, cfg)
}
