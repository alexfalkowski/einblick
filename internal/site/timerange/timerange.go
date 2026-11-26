package timerange

import (
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/net/url"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
)

// ErrInvalidDates identifies missing or malformed exact bounds.
var ErrInvalidDates = errors.New("could not read the submitted dates")

const (
	quarterHour  = 15 * time.Minute
	day          = 24 * time.Hour
	threeDays    = 3 * day
	week         = 7 * day
	recentWindow = "recent"
	oneHour      = "1h"
)

// Selection holds the exact query bounds and the preset to use for the next search.
type Selection struct {
	// StartTime is the inclusive bound in UTC.
	StartTime time.Time

	// EndTime is the exclusive bound in UTC.
	EndTime time.Time

	// SearchWindow is the preset to submit with the next search. An empty value keeps the exact bounds on form submission.
	SearchWindow string
}

// Preset is an available duration in the browser's time picker.
type Preset struct {
	// Value is the duration submitted by the browser.
	Value string

	// Label identifies the localized text for the preset.
	Label string

	duration time.Duration
}

var presets = []Preset{
	{Value: "15m", Label: "time_range.15_minutes", duration: quarterHour},
	{Value: oneHour, Label: "time_range.one_hour", duration: time.Hour},
	{Value: "24h", Label: "time_range.24_hours", duration: day},
	{Value: "3d", Label: "time_range.three_days", duration: threeDays},
	{Value: "7d", Label: "time_range.seven_days", duration: week},
}

// Resolve applies a supported window against now or reads an exact RFC 3339 interval.
// A supplied window takes precedence over exact bounds. With neither, Resolve uses the default window.
// The query repository validates whether the resulting exact bounds are usable for its data.
func Resolve(values url.Values, now time.Time, maxRange time.Duration) (Selection, error) {
	window := values.Get("window")
	if strings.IsEmpty(window) {
		if values.Has("start_time") || values.Has("end_time") {
			return exactSelection(values.Get("start_time"), values.Get("end_time"))
		}
		window = defaultWindow(maxRange)
	}

	duration := Duration(window, maxRange)
	if duration == 0 {
		return Selection{}, errors.New("unsupported time window")
	}

	end := now.UTC()
	start := end.Add(-duration.Duration())
	if epoch := time.Unix(0).UTC(); start.Before(epoch) {
		start = epoch
	}

	return Selection{StartTime: start, EndTime: end, SearchWindow: window}, nil
}

// ReloadWindow returns the preset for the address bar. An exact selection without
// a preset reloads with the default rolling window.
func (s Selection) ReloadWindow(maxRange time.Duration) string {
	if strings.IsEmpty(s.SearchWindow) {
		return defaultWindow(maxRange)
	}
	return s.SearchWindow
}

// Presets returns the available time picker presets and the value to highlight.
func (s Selection) Presets(maxRange time.Duration) ([]Preset, string) {
	var applied time.Duration
	if !strings.IsEmpty(s.SearchWindow) {
		applied = time.Duration(s.EndTime.Sub(s.StartTime))
	}

	options := make([]Preset, 0, len(presets))
	selected := strings.Empty
	for _, preset := range presets {
		if preset.duration <= maxRange {
			options = append(options, preset)
			if preset.duration == applied {
				selected = preset.Value
			}
		}
	}

	if len(options) == 0 {
		options = append(options, Preset{Value: recentWindow, Label: "time_range.recent", duration: maxRange})
		if applied == maxRange {
			selected = recentWindow
		}
	}
	return options, selected
}

// Duration returns the preset's duration within maxRange. Zero denotes an unsupported preset.
func Duration(window string, maxRange time.Duration) time.Duration {
	if window == recentWindow {
		return maxRange
	}
	for _, preset := range presets {
		if preset.Value == window && preset.duration <= maxRange {
			return preset.duration
		}
	}
	return 0
}

func defaultWindow(maxRange time.Duration) string {
	if maxRange >= time.Hour {
		return oneHour
	}
	return recentWindow
}

func exactSelection(startText, endText string) (Selection, error) {
	var start, end time.Time
	if err := start.UnmarshalText([]byte(startText)); err != nil {
		return Selection{}, errors.Join(ErrInvalidDates, err)
	}
	if err := end.UnmarshalText([]byte(endText)); err != nil {
		return Selection{}, errors.Join(ErrInvalidDates, err)
	}

	return Selection{StartTime: start.UTC(), EndTime: end.UTC()}, nil
}
