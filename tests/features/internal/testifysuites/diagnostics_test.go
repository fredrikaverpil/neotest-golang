package testifysuites

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestHints(t *testing.T) {
	t.Log("hello world")
	t.Error("whuat")

	// Isn't shown
	assert.False(t, true)
	assert.Falsef(t, true, "we wanted false, but got true")

	t.Log("goodbye world")
}
