package teststates

import (
	"testing"
)

// Test that passes normally
func TestPassing(t *testing.T) {
	// This test passes
}

// Another test that passes
func TestAlsoPassing(t *testing.T) {
	// This test also passes
}

// Test that fails
func TestFailing(t *testing.T) {
	t.Error("this test intentionally fails")
}

// Test that is skipped
func TestSkipped(t *testing.T) {
	t.Skip("this test is intentionally skipped")
}

// Another test that is skipped
func TestAlsoSkipped(t *testing.T) {
	t.Skip("this test is also intentionally skipped")
}

// Test with subtest that fails
func TestWithFailingSubtest(t *testing.T) {
	t.Run("SubtestPassing", func(t *testing.T) {
		// This subtest passes
	})

	t.Run("SubtestFailing", func(t *testing.T) {
		t.Error("this subtest intentionally fails")
	})
}

// Test with subtest that is skipped
func TestWithSkippedSubtest(t *testing.T) {
	t.Run("SubtestPassing", func(t *testing.T) {
		// This subtest passes
	})

	t.Run("SubtestSkipped", func(t *testing.T) {
		t.Skip("this subtest is intentionally skipped")
	})
}