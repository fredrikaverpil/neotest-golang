package sanitization

import (
	"crypto/rand"
	"os"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestSanitization(t *testing.T) {
	b := make([]byte, 1000) // generate random bytes
	_, err := rand.Read(b)
	require.NoError(t, err)
	os.Stdout.Write(b) // write garbage to stdout
}
