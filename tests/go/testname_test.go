package main

import "testing"

// A dummy test, just to assert that Go tests can run.
func TestNames(t *testing.T) {
	t.Run("Mixed case with space", func(t *testing.T) {
		if Add(1, 2) != 3 {
			t.Fail()
		}
	})

	t.Run("Comma , and ' are ok to use", func(t *testing.T) {
		if Add(1, 2) != 3 {
			t.Fail()
		}
	})

	t.Run("Brackets [1] (2) {3} are ok", func(t *testing.T) {
		if Add(1, 2) != 3 {
			t.Fail()
		}
	})
}
