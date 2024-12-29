package operand

import "testing"

type dummy struct{}

func (dummy) Run(string, func(t *testing.T)) {}

func Test_Run(t *testing.T) {
	t.Run("find me", func(t *testing.T) {
	})

	x := dummy{}
	x.Run("don't find me", func(t *testing.T) {
	})

	router := dummy{}
	router.Run("don't find me", func(t *testing.T) {
	})
}

func Benchmark_Run(b *testing.B) {
	// NOTE: support for benchmarks could potentially be added.
	b.Run("benchmark case", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			// Add benchmark logic here
			dummy{}.Run("test", func(t *testing.T) {})
		}
	})
}

func FuzzRun(f *testing.F) {
	// NOTE: support for fuzz tests could potentially be added.

	// Add seed corpus
	f.Add("test input")

	// Actual fuzz test
	f.Fuzz(func(t2 *testing.T, input string) {
		t := dummy{}
		t.Run(input, func(t *testing.T) {
			// Add fuzzing logic here
		})
	})
}
