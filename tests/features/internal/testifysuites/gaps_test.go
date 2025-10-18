package testifysuites

import (
	"testing"

	"github.com/stretchr/testify/suite"
)

// GapSuite tests the non-contiguous method handling
type GapSuite struct {
	suite.Suite
}

// TestFirst is a contiguous method at line 14
func (s *GapSuite) TestFirst() {
	s.Equal(1, 1)
}

// TestSecond is also contiguous (small gap from TestFirst)
func (s *GapSuite) TestSecond() {
	s.Equal(2, 2)
}

// Many blank lines to create a gap > 20 lines from TestSecond

// TestThird is non-contiguous (gap > 20 lines from TestSecond at line 19)
// This method should appear at root level but still execute with the suite
func (s *GapSuite) TestThird() {
	s.Equal(3, 3)
}

// TestFourth is contiguous with TestThird
func (s *GapSuite) TestFourth() {
	s.Equal(4, 4)
}

func TestGapSuite(t *testing.T) {
	suite.Run(t, new(GapSuite))
}
