package testify

// Basic imports
import (
	"testing"

	"github.com/stretchr/testify/suite"
)

type OtherTestSuite struct {
	suite.Suite
	VariableThatShouldStartAtFive int
}

// A second suite setup method.
func (suite *OtherTestSuite) SetupTest() {
	suite.VariableThatShouldStartAtFive = 5
}

func TestOtherTestSuite(t *testing.T) {
	s := &OtherTestSuite{}
	suite.Run(t, s)
}
