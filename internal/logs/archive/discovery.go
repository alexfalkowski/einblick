package archive

import (
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
)

const utcDay = 24 * time.Hour

// DayStart returns midnight UTC at the start of the archive day containing t.
func DayStart(t time.Time) time.Time {
	return t.UTC().Truncate(utcDay.Duration())
}

// LocalWindowStart returns the start of the previous UTC event day.
func LocalWindowStart(t time.Time) time.Time {
	return DayStart(t).AddDate(0, 0, -1)
}

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
	firstDay := DayStart(start)
	lastDay := DayStart(end.Add(-time.Nanosecond.Duration()))
	logPrefix := strings.Concat(Version, "/", logDayPrefix)
	startAfter := strings.Concat(logPrefix, firstDay.Format(DayLayout), "/")
	stopBefore := strings.Concat(logPrefix, lastDay.AddDate(0, 0, 1).Format(DayLayout), "/")
	listingPrefix := logPrefix
	if firstDay.Equal(lastDay) {
		listingPrefix = startAfter
	}

	// Keys sort by UTC day. One paginated listing covers the range.
	objects := make(map[string]time.Time)
	for object, err := range store.List(ctx, listingPrefix, startAfter) {
		if err != nil {
			return nil, err
		}

		key := object.Key
		if !strings.HasPrefix(key, listingPrefix) || key <= startAfter {
			continue
		}
		if key >= stopBefore {
			break
		}

		day, filename, _ := strings.Cut(key[len(logPrefix):], "/")
		if _, err := time.Parse(DayLayout, day); err == nil && isBatchFilename(filename) {
			objects[key] = object.StoredAt
		}
	}

	return objects, nil
}
