package naming_test

import (
	"testing"

	"github.com/fredrikaverpil/neotest-golang/internal/naming"
)

func TestBlackBox(t *testing.T) {
	// Can only access Add() through the public interface of package_naming.
	if naming.Add(1, 2) != 3 {
		t.Fail()
	}
}
