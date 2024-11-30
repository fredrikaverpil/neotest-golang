package subpackage

import "testing"

func TestSubpackage(t *testing.T) {
	if (1 + 2) != 3 {
		t.Fail()
	}
}
