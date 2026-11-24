package archive_test

import (
	"testing"
	"time"

	"github.com/alexfalkowski/einblick/internal/logs/archive"
)

func TestStoredAtForExpiration(t *testing.T) {
	headAt := time.Date(2026, time.November, 24, 12, 0, 0, 0, time.UTC)
	listedAt := headAt.Add(750 * time.Millisecond)

	tests := []struct {
		name   string
		listed time.Time
		head   time.Time
		want   time.Time
	}{
		{"precise listing takes precedence over HEAD", listedAt, headAt, listedAt},
		{"legacy object has a known listing time", listedAt, time.Time{}, listedAt},
		{"missing object uses the end of the HEAD second", time.Time{}, headAt, headAt.Add(time.Second)},
		{"missing legacy object has unknown age", time.Time{}, time.Time{}, time.Time{}},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := archive.StoredAtForExpiration(tc.listed, tc.head)
			if !got.Equal(tc.want) {
				t.Errorf("timestamp = %v, want %v", got, tc.want)
			}
		})
	}
}
