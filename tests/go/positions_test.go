package main

import (
	"testing"
)

// Vanilla top-level test.
func TestTopLevel(t *testing.T) {
	if Add(1, 2) != 3 {
		t.Fail()
	}
}

// Top-level test with sub-test.
func TestTopLevelWithSubTest(t *testing.T) {
	t.Run("SubTest", func(t *testing.T) {
		if Add(1, 2) != 3 {
			t.Fail()
		}
	})
}

// Table test defined as struct.
func TestTableTestStruct(t *testing.T) {
	type table struct {
		name string
		x    int
		y    int
		want int
	}

	tt := []table{
		{name: "TableTest1", x: 1, y: 2, want: 3},
		{name: "TableTest2", x: 3, y: 4, want: 7},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			if Add(tc.x, tc.y) != tc.want {
				t.Fail()
			}
		})
	}
}

// Table test defined as struct (in sub-test).
func TestSubTestTableTestStruct(t *testing.T) {
	t.Run("SubTest", func(t *testing.T) {
		type table struct {
			name string
			x    int
			y    int
			want int
		}

		tt := []table{
			{name: "TableTest1", x: 1, y: 2, want: 3},
			{name: "TableTest2", x: 3, y: 4, want: 7},
		}

		for _, tc := range tt {
			t.Run(tc.name, func(t *testing.T) {
				if Add(tc.x, tc.y) != tc.want {
					t.Fail()
				}
			})
		}
	})
}

// Table test defined as anonymous struct.
func TestTableTestInlineStruct(t *testing.T) {
	tt := []struct {
		name string
		x    int
		y    int
		want int
	}{
		{name: "TableTest1", x: 1, y: 2, want: 3},
		{name: "TableTest2", x: 3, y: 4, want: 7},
	}

	for _, tc := range tt {
		t.Run(tc.name, func(t *testing.T) {
			if Add(tc.x, tc.y) != tc.want {
				t.Fail()
			}
		})
	}
}

// Table test defined as anonymous struct (in sub-test).
func TestSubTestTableTestInlineStruct(t *testing.T) {
	t.Run("SubTest", func(t *testing.T) {
		tt := []struct {
			name string
			x    int
			y    int
			want int
		}{
			{name: "TableTest1", x: 1, y: 2, want: 3},
			{name: "TableTest2", x: 3, y: 4, want: 7},
		}

		for _, tc := range tt {
			t.Run(tc.name, func(t *testing.T) {
				if Add(tc.x, tc.y) != tc.want {
					t.Fail()
				}
			})
		}
	})
}

// Table test defined as anonymous struct in loop.
func TestTableTestInlineStructLoop(t *testing.T) {
	for _, tc := range []struct {
		name     string
		x        int
		y        int
		expected int
	}{
		{name: "TableTest1", x: 1, y: 2, expected: 3},
		{name: "TableTest2", x: 3, y: 4, expected: 7},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if Add(tc.x, tc.y) != tc.expected {
				t.Fail()
			}
		})
	}
}

// Table test defined as anonymous struct in loop (in sub-test).
func TestSubTestTableTestInlineStructLoop(t *testing.T) {
	t.Run("SubTest", func(t *testing.T) {
		for _, tc := range []struct {
			name     string
			x        int
			y        int
			expected int
		}{
			{name: "TableTest1", x: 1, y: 2, expected: 3},
			{name: "TableTest2", x: 3, y: 4, expected: 7},
		} {
			t.Run(tc.name, func(t *testing.T) {
				if Add(tc.x, tc.y) != tc.expected {
					t.Fail()
				}
			})
		}
	})
}

// Table test defined as map.
func TestTableTestMap(t *testing.T) {
	tt := map[string]struct {
		a    int
		b    int
		want int
	}{
		"TableTest1": {a: 1, b: 1, want: 2},
		"TableTest2": {a: 2, b: 2, want: 4},
	}
	for name, tc := range tt {
		t.Run(name, func(t *testing.T) {
			got := Add(tc.a, tc.b)
			if got != tc.want {
				t.Errorf("got %d, want %d", got, tc.want)
			}
		})
	}
}
