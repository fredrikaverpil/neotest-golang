package streaming_test

import (
	"testing"
	"time"
)

func TestSlowTest1(t *testing.T) {
	t.Log("Starting slow test 1...")
	time.Sleep(2 * time.Second)
	t.Log("Slow test 1 completed")
}

func TestSlowTest2(t *testing.T) {
	t.Log("Starting slow test 2...")
	time.Sleep(3 * time.Second)
	t.Log("Slow test 2 completed")
}

func TestSlowTest3(t *testing.T) {
	t.Log("Starting slow test 3...")
	time.Sleep(1 * time.Second)
	t.Log("Slow test 3 completed")
}

func TestFastTest(t *testing.T) {
	t.Log("Fast test completed immediately")
}
