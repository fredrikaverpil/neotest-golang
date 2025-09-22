package testifysuites

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/suite"
)

func TestMapTestSuite(t *testing.T) {
	suite.Run(t, new(mapTestSuite))
}

type mapTestSuite struct {
	suite.Suite
}

func (s *mapTestSuite) TestNeotestGolangMap() {
	tests := map[string]struct {
		a int
		b string
	}{
		"test 1": {
			a: 1,
			b: "some name",
		},
		"test 2": {
			a: 2,
			b: "another name",
		},
	}

	for name, tt := range tests {
		s.Run(name, func() {
			assert.Equal(s.T(), tt.a, tt.a) // Fix: use actual value instead of hardcoded 1
			assert.Equal(s.T(), tt.b, tt.b) // Fix: use actual value instead of hardcoded string
		})
	}
}

// Regular function (not suite method) for comparison
func Test_NeotestGolangMapNoSuite(t *testing.T) {
	tests := map[string]struct {
		a int
		b string
	}{
		"test 1": {
			a: 1,
			b: "some name",
		},
	}

	for name, tc := range tests {
		t.Run(name, func(tt *testing.T) {
			assert.Equal(tt, tc.a, 1)
			assert.Equal(tt, tc.b, "some name")
		})
	}
}
