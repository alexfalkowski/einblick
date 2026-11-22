package archive

import (
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
)

const utcDay = 24 * time.Hour

// Discover returns v1 log object keys from UTC days that overlap [start, end).
// Each day has a prefix such as v1/signal=logs/day=2026-11-19/.
func Discover(ctx context.Context, store ObjectStore, start, end time.Time) (map[string]struct{}, error) {
	keys := make(map[string]struct{})
	firstDay := start.UTC().Truncate(utcDay.Duration())

	for day := firstDay; day.Before(end); day = day.AddDate(0, 0, 1) {
		prefix := strings.Concat(Version, "/", dayPath(day.Format(DayLayout)))
		for key, err := range store.List(ctx, prefix) {
			if err != nil {
				return nil, err
			}

			if !strings.HasPrefix(key, prefix) {
				continue
			}
			filename := strings.TrimPrefix(key, prefix)
			if isBatchFilename(filename) {
				keys[key] = struct{}{}
			}
		}
	}

	return keys, nil
}
