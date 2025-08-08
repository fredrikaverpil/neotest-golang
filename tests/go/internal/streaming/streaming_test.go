package streaming

import (
	"testing"
)

func TestFast(t *testing.T) {
	// This test completes quickly
	t.Log("Fast test running")
}

func TestSlow(t *testing.T) {
	// This test takes some time
	t.Log("Slow test starting")
	// time.Sleep(5 * time.Second)
	t.Log("Slow test completed")
}

func TestWithSubtests(t *testing.T) {
	t.Parallel()
	t.Run("Subtest1", func(t *testing.T) {
		t.Parallel()
		t.Log("Subtest 1 running")
		// time.Sleep(2 * time.Second)
	})

	t.Run("Subtest2", func(t *testing.T) {
		t.Parallel()
		t.Log("Subtest 2 running")
		// time.Sleep(10 * time.Second)
	})
}

func TestSkipped(t *testing.T) {
	t.Skip("Skipping this test")
}
