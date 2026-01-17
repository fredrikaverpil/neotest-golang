package testifysuites

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/suite"
)

// Regular Go test function with subtests using t.Run().
func TestRegularWithSubtests(t *testing.T) {
	t.Run("RegularSubtest1", func(t *testing.T) {
		assert.Equal(t, 1, 1)
	})

	t.Run("RegularSubtest2", func(t *testing.T) {
		assert.Equal(t, 2, 2)
	})
}

// Another regular Go test without subtests.
func TestRegularWithoutSubtests(t *testing.T) {
	assert.Equal(t, 3, 3)
}

// Testify suite definition.
type MixedTestSuite struct {
	suite.Suite
	counter int
}

func (suite *MixedTestSuite) SetupTest() {
	suite.counter = 0
}

// Testify suite method without subtests.
func (suite *MixedTestSuite) TestSuiteMethod1() {
	suite.Equal(0, suite.counter)
}

// Testify suite method with subtests using suite.Run().
func (suite *MixedTestSuite) TestSuiteMethodWithSubtests() {
	suite.Run("SuiteSubtest1", func() {
		suite.counter = 1
		suite.Equal(1, suite.counter)
	})

	suite.Run("SuiteSubtest2", func() {
		suite.counter = 2
		suite.Equal(2, suite.counter)
	})
}

// Testify suite method with subtests using s.Run().
func (s *MixedTestSuite) TestSuiteMethodWithSubtests2() {
	s.Run("SuiteSubtest3", func() {
		s.counter = 3
		s.Equal(3, s.counter)
	})
}

// Suite runner function.
func TestMixedTestSuite(t *testing.T) {
	suite.Run(t, new(MixedTestSuite))
}
