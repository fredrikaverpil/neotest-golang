package testifysuites

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

// TestHints tests mixed diagnostics (t.Log, t.Error, assert with/without messages)
func TestHints(t *testing.T) {
	t.Log("hello world")
	t.Error("whuat")

	// Testify assertion without custom message
	assert.False(t, true)
	// Testify assertion with custom message
	assert.Falsef(t, true, "not shown")

	t.Log("goodbye world")
}

// TestConsecutiveFailures tests multiple consecutive testify failures
func TestConsecutiveFailures(t *testing.T) {
	// First failure without custom message
	assert.Equal(t, 1, 2)
	// Second failure without custom message
	assert.True(t, false)
	// Third failure with custom message
	assert.Containsf(t, "hello", "x", "expected x in string")
}

// TestMixedAssertTypes tests different assertion types
func TestMixedAssertTypes(t *testing.T) {
	t.Log("starting mixed test")

	// Equal assertion
	assert.Equal(t, "expected", "actual", "values should match")

	t.Error("manual error in between")

	// Contains assertion
	assert.Contains(t, []int{1, 2, 3}, 5, "slice should contain 5")

	// NotNil assertion
	assert.NotNil(t, nil, "should not be nil")
}
