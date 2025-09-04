package customtestify

// Custom imports with different identifiers
import (
	"testing"

	customSuite "github.com/stretchr/testify/suite"
)

// Test suite using custom operand 'x' instead of 'suite'
type CustomTestSuite struct {
	customSuite.Suite
}

// Test method using custom operand 'x'
func (x *CustomTestSuite) TestWithCustomOperand() {
	x.Run("custom subtest", func() {
		x.T().Log("This subtest uses custom operand 'x'")
	})
}

// Another test method using custom operand 'x'
func (x *CustomTestSuite) TestCustomPattern() {
	x.T().Log("Testing custom testify pattern")
}

// Standard test runner function
func TestCustomTestSuite(t *testing.T) {
	customSuite.Run(t, new(CustomTestSuite))
}
