package main

import "github.com/fredrikaverpil/bld"

var Config = bld.Config{
	Go: &bld.GoConfig{
		Modules: map[string]bld.GoModuleOptions{
			"tests/go":       {SkipLint: true, SkipTest: true},
			"tests/features": {SkipLint: true, SkipTest: true},
		},
	},
	Markdown: &bld.MarkdownConfig{},
	GitHub:   &bld.GitHubConfig{},
}
