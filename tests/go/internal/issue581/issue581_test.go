package issue581

import (
	"fmt"
	"testing"
)

// Regression test for https://github.com/fredrikaverpil/neotest-golang/issues/581
//
// Table-driven tests with many cases used to have their leading cases silently
// dropped during tree-sitter discovery. A single query bound every struct
// element to the trailing `for ... t.Run(...)` loop, so tree-sitter kept one
// in-progress match alive per element until the loop; once the number of
// in-progress matches exceeded the match limit (256 by default in Neovim), the
// earliest-starting matches were evicted. With the combined query these tables
// dropped their first 29 of 50 cases (only 21 detected).
//
// Each table below has enough cases to have exceeded that limit; every case
// must now be discovered. All four rewritten discovery shapes are covered:
// keyed slice, unkeyed slice, map, and inline slice.
const caseCount = 50

func caseName(i int) string { return fmt.Sprintf("case - %02d", i) }

func TestManyKeyedCases(t *testing.T) {
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
		t.Run(tc.name, func(t *testing.T) { fmt.Println(tc.content) })
	}
}

func TestManyUnkeyedCases(t *testing.T) {
	testCases := []struct {
		name    string
		content string
	}{
		{"case - 01", "payload"},
		{"case - 02", "payload"},
		{"case - 03", "payload"},
		{"case - 04", "payload"},
		{"case - 05", "payload"},
		{"case - 06", "payload"},
		{"case - 07", "payload"},
		{"case - 08", "payload"},
		{"case - 09", "payload"},
		{"case - 10", "payload"},
		{"case - 11", "payload"},
		{"case - 12", "payload"},
		{"case - 13", "payload"},
		{"case - 14", "payload"},
		{"case - 15", "payload"},
		{"case - 16", "payload"},
		{"case - 17", "payload"},
		{"case - 18", "payload"},
		{"case - 19", "payload"},
		{"case - 20", "payload"},
		{"case - 21", "payload"},
		{"case - 22", "payload"},
		{"case - 23", "payload"},
		{"case - 24", "payload"},
		{"case - 25", "payload"},
		{"case - 26", "payload"},
		{"case - 27", "payload"},
		{"case - 28", "payload"},
		{"case - 29", "payload"},
		{"case - 30", "payload"},
		{"case - 31", "payload"},
		{"case - 32", "payload"},
		{"case - 33", "payload"},
		{"case - 34", "payload"},
		{"case - 35", "payload"},
		{"case - 36", "payload"},
		{"case - 37", "payload"},
		{"case - 38", "payload"},
		{"case - 39", "payload"},
		{"case - 40", "payload"},
		{"case - 41", "payload"},
		{"case - 42", "payload"},
		{"case - 43", "payload"},
		{"case - 44", "payload"},
		{"case - 45", "payload"},
		{"case - 46", "payload"},
		{"case - 47", "payload"},
		{"case - 48", "payload"},
		{"case - 49", "payload"},
		{"case - 50", "payload"},
	}
	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) { fmt.Println(tc.content) })
	}
}

func TestManyMapCases(t *testing.T) {
	testCases := map[string]struct {
		content string
	}{
		"case - 01": {content: "payload"},
		"case - 02": {content: "payload"},
		"case - 03": {content: "payload"},
		"case - 04": {content: "payload"},
		"case - 05": {content: "payload"},
		"case - 06": {content: "payload"},
		"case - 07": {content: "payload"},
		"case - 08": {content: "payload"},
		"case - 09": {content: "payload"},
		"case - 10": {content: "payload"},
		"case - 11": {content: "payload"},
		"case - 12": {content: "payload"},
		"case - 13": {content: "payload"},
		"case - 14": {content: "payload"},
		"case - 15": {content: "payload"},
		"case - 16": {content: "payload"},
		"case - 17": {content: "payload"},
		"case - 18": {content: "payload"},
		"case - 19": {content: "payload"},
		"case - 20": {content: "payload"},
		"case - 21": {content: "payload"},
		"case - 22": {content: "payload"},
		"case - 23": {content: "payload"},
		"case - 24": {content: "payload"},
		"case - 25": {content: "payload"},
		"case - 26": {content: "payload"},
		"case - 27": {content: "payload"},
		"case - 28": {content: "payload"},
		"case - 29": {content: "payload"},
		"case - 30": {content: "payload"},
		"case - 31": {content: "payload"},
		"case - 32": {content: "payload"},
		"case - 33": {content: "payload"},
		"case - 34": {content: "payload"},
		"case - 35": {content: "payload"},
		"case - 36": {content: "payload"},
		"case - 37": {content: "payload"},
		"case - 38": {content: "payload"},
		"case - 39": {content: "payload"},
		"case - 40": {content: "payload"},
		"case - 41": {content: "payload"},
		"case - 42": {content: "payload"},
		"case - 43": {content: "payload"},
		"case - 44": {content: "payload"},
		"case - 45": {content: "payload"},
		"case - 46": {content: "payload"},
		"case - 47": {content: "payload"},
		"case - 48": {content: "payload"},
		"case - 49": {content: "payload"},
		"case - 50": {content: "payload"},
	}
	for name, tc := range testCases {
		t.Run(name, func(t *testing.T) { fmt.Println(tc.content) })
	}
}

func TestManyInlineCases(t *testing.T) {
	for _, tc := range []struct {
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
	} {
		t.Run(tc.name, func(t *testing.T) { fmt.Println(tc.content) })
	}
}
