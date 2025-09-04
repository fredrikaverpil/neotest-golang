package envtest

import (
	"os"
	"testing"
)

func TestEnvironmentVariables(t *testing.T) {
	// Check for test environment variables
	testVar1 := os.Getenv("NEOTEST_GO_VAR1")
	testVar2 := os.Getenv("NEOTEST_GO_VAR2")

	if testVar1 != "" {
		t.Logf("Found NEOTEST_GO_VAR1: %s", testVar1)
	}

	if testVar2 != "" {
		t.Logf("Found NEOTEST_GO_VAR2: %s", testVar2)
	}

	// This test passes regardless, but logs environment variables if present
	// It's used to verify that environment variable injection is working
	t.Log("Environment variable test completed")
}

func TestCustomEnvironmentVariable(t *testing.T) {
	customVar := os.Getenv("CUSTOM_ENV_VAR")
	if customVar != "" {
		t.Logf("Found CUSTOM_ENV_VAR: %s", customVar)
	} else {
		t.Log("CUSTOM_ENV_VAR not set, which is fine for basic test")
	}
}
