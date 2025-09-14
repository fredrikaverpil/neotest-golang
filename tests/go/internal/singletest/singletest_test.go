package singletest

import "testing"

func TestOne(t *testing.T) {
	// This test should run when using pattern "TestOne"
}

func TestTwo(t *testing.T) {
	// This test should NOT run when using pattern "TestOne" or "^TestOne$"
}

func TestThree(t *testing.T) {
	// This test should NOT run when using pattern "TestOne" or "^TestOne$"
}
