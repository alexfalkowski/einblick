package model

import (
	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/einblick/internal/site/logs/query"
	"github.com/alexfalkowski/go-service/v3/time"
)

// Activity presents the matching count and its distribution for an applied search.
type Activity struct {
	// TickFormat is the localized time format key for the current resolution.
	TickFormat string

	// IntervalUnit is the localized unit key for the time saved in IntervalSize.
	IntervalUnit string

	// Bars are ordered by event-time interval.
	Bars []ActivityBar

	// Ticks label selected time boundaries across the chart.
	Ticks []ActivityTick

	// Total is the exact number of matching records at the time of the query.
	Total int64

	// IntervalSize is the number of units in each full bucket.
	IntervalSize int64
}

// ActivityBar shows one event-time interval in the activity chart.
type ActivityBar struct {
	storage.ActivityBucket

	// SearchURL opens the bucket's exact bounds with the applied filters.
	SearchURL string

	// Height is the percentage of the busiest bucket's count.
	Height int
}

// ActivityTick labels the time at a bar boundary on the horizontal axis.
type ActivityTick struct {
	// Time is the UTC boundary displayed under the chart.
	Time time.Time

	// Position is the boundary's percentage of chart width.
	Position int

	// WideOnly hides intermediate ticks when the chart has limited space.
	WideOnly bool
}

// NewActivity scales the chart to the largest bucket and sums its counts.
func NewActivity(data *storage.Activity, search query.Search) *Activity {
	const fullHeight = 100

	intervalSize, intervalUnit := activityInterval(data.Interval)
	activity := &Activity{
		Bars: make([]ActivityBar, len(data.Buckets)), Ticks: activityTicks(data.Buckets),
		TickFormat: "logs.activity_tick_format", IntervalUnit: intervalUnit, IntervalSize: intervalSize,
	}
	if data.Interval < time.Minute {
		activity.TickFormat = "logs.event_format"
	}
	var peak int64
	for _, bucket := range data.Buckets {
		activity.Total += bucket.Count
		peak = max(peak, bucket.Count)
	}
	for index, bucket := range data.Buckets {
		bar := ActivityBar{ActivityBucket: bucket, SearchURL: search.RangeURL(bucket.StartTime, bucket.EndTime)}
		if bucket.Count > 0 {
			bar.Height = max(1, int(float64(bucket.Count)/float64(peak)*fullHeight))
		}
		activity.Bars[index] = bar
	}
	return activity
}

func activityInterval(width time.Duration) (int64, string) {
	const day = 24 * time.Hour
	switch {
	case width >= day:
		return int64(width / day), "logs.activity_days"
	case width >= time.Hour:
		return int64(width / time.Hour), "logs.activity_hours"
	case width >= time.Minute:
		return int64(width / time.Minute), "logs.activity_minutes"
	default:
		return int64(width / time.Second), "logs.activity_seconds"
	}
}

func activityTicks(buckets []storage.ActivityBucket) []ActivityTick {
	const axisWidth, quarterCount, midpoint = 100, 4, 2
	ticks := []ActivityTick{{Time: buckets[0].StartTime}}
	for quarter := 1; quarter < quarterCount; quarter++ {
		wide := quarter != midpoint
		if len(buckets) < quarterCount || (wide && len(buckets) < 2*quarterCount) {
			continue
		}
		index := len(buckets) * quarter / quarterCount
		ticks = append(ticks, ActivityTick{Time: buckets[index].StartTime, Position: index * axisWidth / len(buckets), WideOnly: wide})
	}
	return append(ticks, ActivityTick{Time: buckets[len(buckets)-1].EndTime, Position: axisWidth})
}
