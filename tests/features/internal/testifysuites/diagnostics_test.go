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
	assert.Falsef(t, true, "no shown")

	t.Log("goodbye world")
}
