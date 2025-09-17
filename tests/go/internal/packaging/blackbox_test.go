package packaging_test

import (
	"testing"

	"github.com/fredrikaverpil/neotest-golang/internal/packaging"
)

func TestBlackBox(t *testing.T) {
	// Can only access Add() through the public interface of "packaging".
	if packaging.Add(1, 2) != 3 {
		t.Fail()
	}
}
