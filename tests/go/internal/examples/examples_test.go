package examples

import (
	"fmt"
	"testing"
)

// Regular test to ensure Tests and Examples can coexist
func TestAdd(t *testing.T) {
	result := Add(2, 2)
	if result != 4 {
		t.Errorf("Add(2, 2) = %d; want 4", result)
	}
}

// Package-level example (should pass)
func Example() {
	fmt.Println("examples package")
	// Output: examples package
}

// Example for Add function (should pass)
func ExampleAdd() {
	sum := Add(2, 2)
	fmt.Println(sum)
	// Output: 4
}

// Example that should fail (incorrect output comment)
func ExampleAdd_failing() {
	sum := Add(3, 3)
	fmt.Println(sum)
	// Output: 5
}

// Example for Multiply function (should pass)
func ExampleMultiply() {
	product := Multiply(3, 4)
	fmt.Println(product)
	// Output: 12
}

// Example with multiple outputs (should pass)
func ExampleMultiply_second() {
	fmt.Println(Multiply(2, 3))
	fmt.Println(Multiply(4, 5))
	// Output:
	// 6
	// 20
}

// Example that demonstrates method-style naming (should fail)
func ExampleCalculator_Add() {
	result := Add(10, 5)
	fmt.Println(result)
	// Output: 100
}
