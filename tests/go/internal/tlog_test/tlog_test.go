package tlog_test

import (
	"testing"
)

func TestLogOutput(t *testing.T) {
	t.Log("This is a t.Log message - should be treated as hint, not error")

	// This should pass
	if 1+1 == 2 {
		t.Log("Math works correctly")
	}
}

func TestLogOutputWithFailure(t *testing.T) {
	t.Log("Starting test with some logging")

	// This will fail
	if 1+1 == 3 {
		t.Log("This log won't be reached")
	} else {
		t.Log("Math check failed as expected")
		t.Error("Expected 1+1 to equal 3, but it equals 2")
	}
}

func TestMultipleLogs(t *testing.T) {
	t.Log("First log message")
	t.Log("Second log message with some details: value=42")
	t.Log("Third log message with multiline content\nLine 2 of the log\nLine 3 of the log")

	// Test passes
	if 2*2 == 4 {
		t.Log("Multiplication works")
	}
}

func TestLogAndLogf(t *testing.T) {
	t.Log("Using t.Log")
	t.Logf("Using t.Logf with formatting: %d + %d = %d", 5, 3, 8)

	// Pass the test
	if 5+3 == 8 {
		t.Log("Addition verified")
	}
}
