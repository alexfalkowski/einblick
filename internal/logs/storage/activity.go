package storage

import (
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/database/sql"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
)

const (
	// activityBars is the display budget for a single series in the Logs panel.
	activityBars = 60
	day          = 24 * time.Hour
)

// Activity counts events in UTC-aligned time buckets.
type Activity struct {
	// Buckets cover the requested interval, including buckets with zero matches.
	Buckets []ActivityBucket

	// Interval is the full width before clipping the two edge buckets.
	Interval time.Duration
}

// ActivityBucket counts matching events in one part of the requested interval.
type ActivityBucket struct {
	// StartTime is the inclusive event-time bound.
	StartTime time.Time

	// EndTime is the exclusive event-time bound.
	EndTime time.Time

	// Count includes every matching record in the bucket.
	Count int64
}

func (r *repository) Activity(ctx context.Context, query Query) (*Activity, error) {
	if !strings.IsEmpty(query.PageToken) {
		return nil, ErrInvalidQuery
	}

	var activity *Activity
	err := r.search(ctx, query, activitySearch, func(ctx context.Context, query Query) error {
		span := time.Duration(query.EndTime.Sub(query.StartTime))
		width := activityWidth(span)
		origin := query.StartTime.Truncate(width.Duration())
		args := append(filterArgs(query), unixNanoseconds(origin).String(), int64(width))

		return r.queryLogs(ctx, query, logActivityQuery, args, func(rows *sql.Rows) error {
			buckets := activityBuckets(query, origin, width)
			for rows.Next() {
				var index int
				var count int64
				if err := rows.Scan(&index, &count); err != nil {
					return err
				}
				buckets[index].Count = count
			}

			activity = &Activity{Buckets: buckets, Interval: width}

			return rows.Err()
		})
	})
	if err != nil {
		return nil, err
	}
	return activity, nil
}

func activityBuckets(query Query, origin time.Time, width time.Duration) []ActivityBucket {
	buckets := make([]ActivityBucket, 0, activityBars)
	for start := origin; start.Before(query.EndTime); start = start.Add(width.Duration()) {
		first, last := start, start.Add(width.Duration())
		if first.Before(query.StartTime) {
			first = query.StartTime
		}
		if query.EndTime.Before(last) {
			last = query.EndTime
		}
		buckets = append(buckets, ActivityBucket{StartTime: first, EndTime: last})
	}
	return buckets
}

func activityWidth(span time.Duration) time.Duration {
	// Leave room for a clipped first bucket when the search starts between UTC boundaries.
	minimum := (span-1)/(activityBars-1) + 1
	for _, width := range []time.Duration{time.Second, time.Minute, 5 * time.Minute, 15 * time.Minute, time.Hour, 6 * time.Hour, day} {
		if width >= minimum {
			return width
		}
	}
	return ((minimum-1)/day + 1) * day
}
