package diagnostics

import "testing"

type dummy struct{}

func (dummy) Run(string, func(t *testing.T)) {}

func TestDiagnosticsTopLevelLog(t *testing.T) {
	t.Log("top-level hint: this should be classified as a hint")
}

func TestDiagnosticsTopLevelError(t *testing.T) {
	t.Error("expected 42 but got 0")
}

func TestDiagnosticsTopLevelSkip(t *testing.T) {
	t.Skip("not implemented yet")
}

func TestDiagnosticsTopLevelPanic(t *testing.T) {
	var s []int
	_ = s[1] // panic: runtime error: index out of range
}

func TestDiagnosticsSubTests(t *testing.T) {
	t.Run("log", func(t *testing.T) {
		t.Log("I'm a logging hint message")
	})

	t.Run("error", func(t *testing.T) {
		t.Error("I'm an error message")
	})

	t.Run("skip", func(t *testing.T) {
		t.Skip("I'm a skip message")
	})

	// NOTE: this does not work as expected...?
	// t.Run("panic", func(t *testing.T) {
	// 	var s []int
	// 	_ = s[1] // panic: runtime error: index out of range
	// })
}
