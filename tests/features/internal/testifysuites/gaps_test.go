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

// ============================================================================
// Large gap below to test non-contiguous method handling
// ============================================================================
//
// The following comments create a gap of >20 lines between TestSecond and
// TestThird to verify that neotest-golang correctly handles non-contiguous
// testify suite methods.
//
// When methods are separated by more than MAX_GAP (20) lines, they should:
// 1. Be moved to root level in the Neotest tree (not nested under namespace)
// 2. Still retain their suite namespace in the test ID for correct execution
// 3. Execute properly with: go test -run TestGapSuite/TestThird
//
// This ensures the "run nearest test" feature works correctly in large files
// where suite methods might be spread throughout the file.
//
// Additional padding lines to ensure gap > 20:
// ...
// ...
// ...
//
// ============================================================================
// End of gap - TestThird should be non-contiguous from TestSecond
// ============================================================================

// TestThird is non-contiguous (gap > 20 lines from TestSecond)
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
