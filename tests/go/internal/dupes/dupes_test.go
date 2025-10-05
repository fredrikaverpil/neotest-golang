package dupes

import "testing"

// TestRegressuion demonstrates what should _not_ be flagged as a duplicate.
// This was fixed in PR #461.
func TestRegression(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{"xx empty string", "", ""},
		{"yy empty string", "", ""},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Logf("Name is: %q", tt.name)
		})
	}
}

// NOTE: enable me to see dupe detection in action
// func TestNoDupe(t *testing.T) {
// 	t.Run("foo", func(t *testing.T) {
// 		t.Run("bar", func(t *testing.T) {
// 		})
// 	})
// 	t.Run("foo", func(t *testing.T) {
// 		t.Run("baz", func(t *testing.T) {
// 		})
// 	})
// }
//
// func TestDupe(t *testing.T) {
// 	t.Run("foo", func(t *testing.T) {
// 		t.Run("bar", func(t *testing.T) {
// 		})
// 	})
// 	t.Run("foo", func(t *testing.T) {
// 		t.Run("bar", func(t *testing.T) {
// 		})
// 	})
// }
