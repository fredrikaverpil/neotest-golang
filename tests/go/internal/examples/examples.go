// Package examples provides simple math operations for testing Example functions
package examples

// Add returns the sum of two integers
func Add(a, b int) int {
	return a + b
}

// Multiply returns the product of two integers
func Multiply(a, b int) int {
	return a * b
}

// Calculator is a simple calculator type
type Calculator struct{}

// Add method on Calculator
func (c Calculator) Add(a, b int) int {
	return Add(a, b)
}
