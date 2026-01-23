package main

import (
	"context"
	"flag"
	"fmt"

	"github.com/fredrikaverpil/pocket/pk"
	"github.com/fredrikaverpil/pocket/tools/uv"
)

// Zensical task flags.
var (
	zensicalFlags = flag.NewFlagSet("zensical", flag.ContinueOnError)
	zensicalServe = zensicalFlags.Bool("serve", false, "serve docs locally")
	zensicalBuild = zensicalFlags.Bool("build", false, "build documentation")
)

// Zensical builds or serves documentation using zensical.
// Usage: ./pok zensical -build|-serve
var Zensical = pk.NewTask("zensical", "build or serve documentation", zensicalFlags,
	pk.Serial(
		uv.Install,
		pk.Do(func(ctx context.Context) error {
			if !*zensicalBuild && !*zensicalServe {
				return fmt.Errorf("must specify either -build or -serve")
			}
			if *zensicalBuild && *zensicalServe {
				return fmt.Errorf("cannot specify both -build and -serve")
			}
			if err := uv.Sync(ctx, "", true); err != nil {
				return err
			}
			if *zensicalServe {
				return uv.Run(ctx, "", "zensical", "serve")
			}
			return uv.Run(ctx, "", "zensical", "build")
		}),
	),
)
