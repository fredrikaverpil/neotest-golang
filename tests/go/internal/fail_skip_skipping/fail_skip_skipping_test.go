package fail_skip_skipping

import (
	"testing"
)

// Test that is skipped
func TestSkipped(t *testing.T) {
	t.Skip("this test is intentionally skipped")
}

// Another test that is skipped
func TestAlsoSkipped(t *testing.T) {
	t.Skip("this test is also intentionally skipped")
}
