package bar_test

import (
	"testing"

	"github.com/stretchr/testify/suite"
)

type TestAlfaSuite struct {
	suite.Suite
}

func (s *TestAlfaSuite) Test_BarFunc() {
	i := 5
	s.Equal(5, i)
}

func Test_TestSuite(t *testing.T) {
	suite.Run(t, new(TestAlfaSuite))
}
