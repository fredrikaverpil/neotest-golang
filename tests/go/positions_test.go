package main

import "testing"

// A dummy test, just to assert that Go tests can run.
func TestAdd(t *testing.T) {
	if Add(1, 2) != 3 {
		t.Fail()
	}
}
