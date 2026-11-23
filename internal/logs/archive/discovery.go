package archive

import (
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
)

const utcDay = 24 * time.Hour

// Object identifies an archive object and when the object store accepted it.
type Object struct {
	// StoredAt is the object timestamp reported by the listing, or zero when unavailable.
	StoredAt time.Time

	// Key is the complete bucket-relative key, including the archive prefix.
	Key string
}

// StoredAtForExpiration prefers the listing timestamp for a retention check.
// For an unlisted object, use the upper bound of HEAD's whole-second precision.
// A zero result indicates unknown age.
func StoredAtForExpiration(listedAt, lastModified time.Time) time.Time {
	if !listedAt.IsZero() {
		return listedAt
	}
	if lastModified.IsZero() {
		return lastModified
	}
	return lastModified.Add(time.Second.Duration())
}

// Discover returns v1 log object keys and storage times for UTC days overlapping [start, end).
// Each day has a prefix such as v1/signal=logs/day=2026-11-19/.
func Discover(ctx context.Context, store ObjectStore, start, end time.Time) (map[string]time.Time, error) {
	objects := make(map[string]time.Time)
	firstDay := start.UTC().Truncate(utcDay.Duration())

	for day := firstDay; day.Before(end); day = day.AddDate(0, 0, 1) {
		prefix := strings.Concat(Version, "/", dayPath(day.Format(DayLayout)))
		for object, err := range store.List(ctx, prefix) {
			if err != nil {
				return nil, err
			}

			if !strings.HasPrefix(object.Key, prefix) {
				continue
			}
			filename := strings.TrimPrefix(object.Key, prefix)
			if isBatchFilename(filename) {
				objects[object.Key] = object.StoredAt
			}
		}
	}

	return objects, nil
}
