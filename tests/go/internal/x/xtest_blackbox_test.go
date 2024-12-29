package x_test

import (
	"testing"

	"github.com/fredrikaverpil/neotest-golang/internal/x"
)

func TestBlackBox(t *testing.T) {
	// Can only access Add() through the public interface of x.
	if x.Add(1, 2) != 3 {
		t.Fail()
	}
}
