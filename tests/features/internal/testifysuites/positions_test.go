package testifysuites

// Basic imports.
import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/suite"
)

// returns the current testing context.
type ExampleTestSuite struct {
	suite.Suite
	VariableThatShouldStartAtFive int
}

// before each test.
func (suite *ExampleTestSuite) SetupTest() {
	suite.VariableThatShouldStartAtFive = 5
}

// All methods that begin with "Test" are run as tests within a
// suite.
func (suite *ExampleTestSuite) TestExample() {
	suite.Equal(5, suite.VariableThatShouldStartAtFive)
}

func (suite *ExampleTestSuite) TestExample2() {
	suite.Equal(5, suite.VariableThatShouldStartAtFive)
}

// a normal test function and pass our suite to suite.Run.
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
	suite.Equal(5, suite.VariableThatShouldStartAtFive)
}

func (suite *ExampleTestSuite2) TestExample2() {
	suite.Equal(5, suite.VariableThatShouldStartAtFive)
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

func (suite *ExampleTestSuite2) TestExample3() {
	suite.Equal(5, suite.VariableThatShouldStartAtFive)
}

// --------------------------------------------------------------------

// A test method which uses a receiver type defined by struct in another file.
func (suite *OtherTestSuite) TestOther() {
	suite.Equal(5, suite.VariableThatShouldStartAtFive)
}

// --------------------------------------------------------------------

// A test method with a subttest, using operand suite.
func (suite *ExampleTestSuite) TestSubTestOperand1() {
	suite.Run("subtest", func() {
		suite.VariableThatShouldStartAtFive = 10
		suite.Equal(10, suite.VariableThatShouldStartAtFive)
	})
}

// A test method with a subttest, using operand s.
func (s *ExampleTestSuite) TestSubTestOperand2() {
	s.Run("subtest", func() {
		s.VariableThatShouldStartAtFive = 10
		s.Equal(10, s.VariableThatShouldStartAtFive)
	})
}
