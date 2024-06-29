package main

import "testing"

func TestTopLevel(t *testing.T) {
	if Add(1, 2) != 3 {
		t.Fail()
	}
}

func TestTopLevelWithSubTest(t *testing.T) {
	t.Run("SubTest", func(t *testing.T) {
		if Add(1, 2) != 3 {
			t.Fail()
		}
	})
}

func TestTopLevelWithTableTests(t *testing.T) {
	tt := []struct {
		name     string
		x        int
		y        int
		expected int
	}{
		{name: "TableTest1", x: 1, y: 2, expected: 3},
		{name: "TableTest2", x: 3, y: 4, expected: 7},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			if Add(tc.x, tc.y) != tc.expected {
				t.Fail()
			}
		})
	}
}

func TestTopLevelWithSubTestWithTableTests(t *testing.T) {
	t.Run("SubTest", func(t *testing.T) {
		tt := []struct {
			name     string
			x        int
			y        int
			expected int
		}{
			{name: "TableTest1", x: 1, y: 2, expected: 3},
			{name: "TableTest2", x: 3, y: 4, expected: 7},
		}

		for _, tc := range tt {
			t.Run(tc.name, func(t *testing.T) {
				if Add(tc.x, tc.y) != tc.expected {
					t.Fail()
				}
			})
		}
	})
}
