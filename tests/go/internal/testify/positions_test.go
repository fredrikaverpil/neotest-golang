package testify

// Basic imports
import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/suite"
)

// Define the suite, and absorb the built-in basic suite
// functionality from testify - including a T() method which
// returns the current testing context
type ExampleTestSuite struct {
	suite.Suite
	VariableThatShouldStartAtFive int
}

// Make sure that VariableThatShouldStartAtFive is set to five
// before each test
func (suite *ExampleTestSuite) SetupTest() {
	suite.VariableThatShouldStartAtFive = 5
}

// All methods that begin with "Test" are run as tests within a
// suite.
func (suite *ExampleTestSuite) TestExample() {
	assert.Equal(suite.T(), 5, suite.VariableThatShouldStartAtFive)
}

func (suite *ExampleTestSuite) TestExample2() {
	assert.Equal(suite.T(), 5, suite.VariableThatShouldStartAtFive)
}

// In order for 'go test' to run this suite, we need to create
// a normal test function and pass our suite to suite.Run
func TestExampleTestSuite(t *testing.T) {
	suite.Run(t, new(ExampleTestSuite))
}

// --------------------------------------------------------------------

// A second suite is defined in the same file.

type ExampleTestSuite2 struct {
	suite.Suite
	VariableThatShouldStartAtFive int
}

func (suite *ExampleTestSuite2) SetupTest() {
	suite.VariableThatShouldStartAtFive = 5
}

func (suite *ExampleTestSuite2) TestExample() {
	assert.Equal(suite.T(), 5, suite.VariableThatShouldStartAtFive)
}

func (suite *ExampleTestSuite2) TestExample2() {
	assert.Equal(suite.T(), 5, suite.VariableThatShouldStartAtFive)
}

func TestExampleTestSuite2(t *testing.T) {
	suite.Run(t, new(ExampleTestSuite2))
}

// --------------------------------------------------------------------

// Just a regular test.
func TestTrivial(t *testing.T) {
	assert.Equal(t, 1, 1)
}

// --------------------------------------------------------------------

// A test method which uses a receiver type defined by struct in another file.
func (suite *OtherTestSuite) TestOther() {
	assert.Equal(suite.T(), 5, suite.VariableThatShouldStartAtFive)
}

// --------------------------------------------------------------------

// A test method with a subttest, using operand suite.
func (suite *ExampleTestSuite) TestSubTestOperand1() {
	suite.Run("subtest", func() {
		suite.VariableThatShouldStartAtFive = 10
		assert.Equal(suite.T(), 10, suite.VariableThatShouldStartAtFive)
	})
}

// A test method with a subttest, using operand s.
func (s *ExampleTestSuite) TestSubTestOperand2() {
	s.Run("subtest", func() {
		s.VariableThatShouldStartAtFive = 10
		assert.Equal(s.T(), 10, s.VariableThatShouldStartAtFive)
	})
}
