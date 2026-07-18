package issue581

import (
	"fmt"
	"testing"
)

// Regression test for https://github.com/fredrikaverpil/neotest-golang/issues/581
//
// Table-driven tests with a large number of cases used to have their leading
// cases silently dropped during tree-sitter discovery: a single query bound
// every struct element to the trailing `for ... t.Run(...)` loop, so tree-sitter
// had to keep one in-progress match alive per element until the loop, and once
// the match limit was exceeded the oldest (leading) matches were evicted.
//
// This table intentionally has enough cases to exceed that old limit; every
// case must be discovered. The corresponding spec asserts all of them are found.
func TestManyTableCases(t *testing.T) {
	testCases := []struct {
		name    string
		content string
	}{
		{name: "case - 01", content: "payload"},
		{name: "case - 02", content: "payload"},
		{name: "case - 03", content: "payload"},
		{name: "case - 04", content: "payload"},
		{name: "case - 05", content: "payload"},
		{name: "case - 06", content: "payload"},
		{name: "case - 07", content: "payload"},
		{name: "case - 08", content: "payload"},
		{name: "case - 09", content: "payload"},
		{name: "case - 10", content: "payload"},
		{name: "case - 11", content: "payload"},
		{name: "case - 12", content: "payload"},
		{name: "case - 13", content: "payload"},
		{name: "case - 14", content: "payload"},
		{name: "case - 15", content: "payload"},
		{name: "case - 16", content: "payload"},
		{name: "case - 17", content: "payload"},
		{name: "case - 18", content: "payload"},
		{name: "case - 19", content: "payload"},
		{name: "case - 20", content: "payload"},
		{name: "case - 21", content: "payload"},
		{name: "case - 22", content: "payload"},
		{name: "case - 23", content: "payload"},
		{name: "case - 24", content: "payload"},
		{name: "case - 25", content: "payload"},
		{name: "case - 26", content: "payload"},
		{name: "case - 27", content: "payload"},
		{name: "case - 28", content: "payload"},
		{name: "case - 29", content: "payload"},
		{name: "case - 30", content: "payload"},
		{name: "case - 31", content: "payload"},
		{name: "case - 32", content: "payload"},
		{name: "case - 33", content: "payload"},
		{name: "case - 34", content: "payload"},
		{name: "case - 35", content: "payload"},
		{name: "case - 36", content: "payload"},
		{name: "case - 37", content: "payload"},
		{name: "case - 38", content: "payload"},
		{name: "case - 39", content: "payload"},
		{name: "case - 40", content: "payload"},
		{name: "case - 41", content: "payload"},
		{name: "case - 42", content: "payload"},
		{name: "case - 43", content: "payload"},
		{name: "case - 44", content: "payload"},
		{name: "case - 45", content: "payload"},
		{name: "case - 46", content: "payload"},
		{name: "case - 47", content: "payload"},
		{name: "case - 48", content: "payload"},
		{name: "case - 49", content: "payload"},
		{name: "case - 50", content: "payload"},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			fmt.Println(tc.content)
		})
	}
}
