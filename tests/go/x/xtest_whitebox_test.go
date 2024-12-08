package x

import "testing"

func TestWhiteBox(t *testing.T) {
	// Can access both Add() and internal()
	if Add(1, 2) != 3 {
		t.Fail()
	}
	if internal() != "private" {
		t.Fail()
	}
}
