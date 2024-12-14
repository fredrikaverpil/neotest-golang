package benchmark

import "testing"

func add(a, b int) int {
	return a + b
}

func multiply(a, b int) int {
	return a * b
}

func BenchmarkOperations(b *testing.B) {
	// TODO: make it possible to run b.Run sub-benchmarks?

	b.Run("Addition", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			add(5, 7)
		}
	})

	b.Run("Multiplication", func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			multiply(5, 7)
		}
	})
}
