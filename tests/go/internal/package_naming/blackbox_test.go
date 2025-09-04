package package_naming_test

import (
	"testing"

	"github.com/fredrikaverpil/neotest-golang/internal/package_naming"
)

func TestBlackBox(t *testing.T) {
	// Can only access Add() through the public interface of package_naming.
	if package_naming.Add(1, 2) != 3 {
		t.Fail()
	}
}
