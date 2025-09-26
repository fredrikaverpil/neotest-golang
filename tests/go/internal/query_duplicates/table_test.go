package query_duplicates

import (
	"testing"
	"time"
)

// Test structure to simulate the user's example
type Event struct {
	EventId   string
	EventTime time.Time
	EventType string
}

func testutils_MustTime(t *testing.T, timeStr string) time.Time {
	parsedTime, err := time.Parse(time.RFC3339, timeStr)
	if err != nil {
		t.Fatalf("Failed to parse time %s: %v", timeStr, err)
	}
	return parsedTime
}

// This test pattern should trigger both table_tests_loop and table_tests_inline_field_access queries
// causing duplicate sub-test detection
func TestMilestonesSorted(t *testing.T) {
	for _, tt := range []struct {
		name     string
		in       []Event
		expected []string
	}{
		{
			name:     "empty",
			in:       []Event{},
			expected: []string{},
		},
		{
			name: "single",
			in: []Event{
				{
					EventId:   "3",
					EventTime: testutils_MustTime(t, "2022-03-12T16:00:00Z"),
					EventType: "milestonePickupStarted",
				},
			},
			expected: []string{"milestoneEvents/3"},
		},
		{
			name: "chronological order",
			in: []Event{
				{
					EventId:   "2",
					EventTime: testutils_MustTime(t, "2022-03-12T14:00:00Z"),
					EventType: "milestonePickupStarted",
				},
				{
					EventId:   "1",
					EventTime: testutils_MustTime(t, "2022-03-12T12:00:00Z"),
					EventType: "milestonePickupStarted",
				},
			},
			expected: []string{"milestoneEvents/1", "milestoneEvents/2"},
		},
		{
			name: "reverse chronological order",
			in: []Event{
				{
					EventId:   "1",
					EventTime: testutils_MustTime(t, "2022-03-12T12:00:00Z"),
					EventType: "milestonePickupStarted",
				},
				{
					EventId:   "2",
					EventTime: testutils_MustTime(t, "2022-03-12T14:00:00Z"),
					EventType: "milestonePickupStarted",
				},
			},
			expected: []string{"milestoneEvents/1", "milestoneEvents/2"},
		},
		{
			name: "random",
			in: []Event{
				{
					EventId:   "4",
					EventTime: testutils_MustTime(t, "2022-03-12T18:00:00Z"),
					EventType: "milestonePickupStarted",
				},
				{
					EventId:   "2",
					EventTime: testutils_MustTime(t, "2022-03-12T14:00:00Z"),
					EventType: "milestonePickupStarted",
				},
				{
					EventId:   "1",
					EventTime: testutils_MustTime(t, "2022-03-12T12:00:00Z"),
					EventType: "milestonePickupStarted",
				},
				{
					EventId:   "3",
					EventTime: testutils_MustTime(t, "2022-03-12T16:00:00Z"),
					EventType: "milestonePickupStarted",
				},
			},
			expected: []string{"milestoneEvents/1", "milestoneEvents/2", "milestoneEvents/3", "milestoneEvents/4"},
		},
	} {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			// Simulate processing logic
			result := make([]string, len(tt.in))
			for i, event := range tt.in {
				result[i] = "milestoneEvents/" + event.EventId
			}

			// Simple assertion
			if len(result) != len(tt.expected) {
				t.Errorf("got %d results, want %d", len(result), len(tt.expected))
			}
		})
	}
}
