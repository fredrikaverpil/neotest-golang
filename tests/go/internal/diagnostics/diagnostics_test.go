package diagnostics

import "testing"

type dummy struct{}

func (dummy) Run(string, func(t *testing.T)) {}

// Subtest with a hint-like log message to verify subtest hints
func TestDiagnostics(t *testing.T) {
	t.Run("log", func(t *testing.T) {
		t.Log("I'm a logging hint message")
	})
}

// Top-level test without subtests that only logs a message.
// Ensures plain tests (no subtests) still surface hint diagnostics.
func TestDiagnosticsTopLevelLog(t *testing.T) {
	t.Log("top-level hint: this should be classified as a hint")
}

// Top-level test that emits an assertion-style message which our
// classifier treats as an error (matches "expected ... but ... got").
func TestDiagnosticsTopLevelError(t *testing.T) {
	t.Skip("remove skip to trigger error")
	t.Error("expected 42 but got 0")
}

// Top-level test that panics with an index-out-of-range to exercise
// the "runtime error" indicator and ensure it's classified as error.
func TestDiagnosticsTopLevelPanic(t *testing.T) {
	t.Skip("remove skip to trigger panic")
	var s []int
	_ = s[1] // panic: runtime error: index out of range
}
