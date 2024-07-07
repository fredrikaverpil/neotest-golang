package main

// Basic imports
import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/suite"
)

type receiverStruct2 struct {
	suite.Suite
	VariableThatShouldStartAtFive int
}

func (suite *receiverStruct2) SetupTest() {
	suite.VariableThatShouldStartAtFive = 5
}

func (suite *receiverStruct2) TestExample3() {
	assert.Equal(suite.T(), 5, suite.VariableThatShouldStartAtFive)
	suite.Equal(5, suite.VariableThatShouldStartAtFive)
}

func (suite *receiverStruct) TestExample4() {
	assert.Equal(suite.T(), 5, suite.VariableThatShouldStartAtFive)
	suite.Equal(5, suite.VariableThatShouldStartAtFive)
}

func TestSuite2(t *testing.T) {
	suite.Run(t, new(receiverStruct2))
}
