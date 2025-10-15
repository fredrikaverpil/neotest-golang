package testifysuites

import (
	"testing"

	"github.com/stretchr/testify/suite"
)

type RegressionSuite struct {
	suite.Suite
}

func (s *RegressionSuite) Test_MyTest1() {
	i := 5
	s.Equal(5, i)
}

func (s *RegressionSuite) Test_MyTest2() {
	i := 5
	s.Equal(5, i)
}

func Test_MySuite(t *testing.T) {
	suite.Run(t, new(RegressionSuite))
}
