package subpackage2

import "testing"

func TestSubpackage2(t *testing.T) {
	if (1 + 2) != 3 {
		t.Fail()
	}
}
