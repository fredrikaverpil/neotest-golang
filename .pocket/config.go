package main

import (
	"github.com/fredrikaverpil/pocket"
	"github.com/fredrikaverpil/pocket/tasks/golang"
	"github.com/fredrikaverpil/pocket/tasks/lua"
	"github.com/fredrikaverpil/pocket/tasks/markdown"
)

var Config = pocket.Config{
	AutoRun: pocket.Parallel(
		// Lua
		pocket.AutoDetect(lua.Tasks()),

		// Markdown
		pocket.AutoDetect(markdown.Tasks()),

		// Go
		pocket.AutoDetect(
			golang.Tasks(
				golang.WithFormat(
					golang.FormatOptions{LintConfig: pocket.FromGitRoot(".golangci.yml")})),
		).Skip(golang.TestTask(), "tests/go", "tests/features"), //
	),
}
