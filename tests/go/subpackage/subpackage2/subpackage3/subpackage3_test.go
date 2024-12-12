package subpackage3

import "testing"

func TestSubpackage3(t *testing.T) {
	if (1 + 2) != 3 {
		t.Fail()
	}
}
