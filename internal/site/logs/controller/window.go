package controller

import (
	"net/url"

	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/einblick/internal/site/logs/model"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
)

var errInvalidDates = errors.New("logs: could not read the submitted dates")

const (
	quarterHour = 15 * time.Minute
	day         = 24 * time.Hour
	threeDays   = 3 * day
	week        = 7 * day
	recentRange = "recent"
)

type timePreset struct {
	option   model.FilterOption
	duration time.Duration
}

type timeWindow struct {
	start  time.Time
	end    time.Time
	recent string
}

var presets = []timePreset{
	{option: model.FilterOption{Value: "15m", Label: "logs.range_15_minutes"}, duration: quarterHour},
	{option: model.FilterOption{Value: "1h", Label: "logs.range_one_hour"}, duration: time.Hour},
	{option: model.FilterOption{Value: "24h", Label: "logs.range_24_hours"}, duration: day},
	{option: model.FilterOption{Value: "3d", Label: "logs.range_three_days"}, duration: threeDays},
	{option: model.FilterOption{Value: "7d", Label: "logs.range_seven_days"}, duration: week},
}

func resolveWindow(form url.Values, maxRange time.Duration) (timeWindow, error) {
	hasCursor := !strings.IsEmpty(form.Get("page_token"))
	if preset := form.Get("window"); !strings.IsEmpty(preset) {
		duration := presetDuration(preset, maxRange)
		if hasCursor || duration == 0 {
			return timeWindow{}, storage.ErrInvalidQuery
		}
		return recentWindow(preset, duration), nil
	}

	hasBounds := form.Has("start_time") || form.Has("end_time") || form.Has("start_utc") || form.Has("end_utc")
	if !hasBounds && !hasCursor {
		return recentWindow(recentRange, maxRange), nil
	}
	return absoluteWindow(form, maxRange, hasCursor)
}

func absoluteWindow(form url.Values, maxRange time.Duration, hasCursor bool) (timeWindow, error) {
	start, err := parseBound(form, "start_time", "start_utc")
	if err != nil {
		return timeWindow{}, errors.Join(errInvalidDates, err)
	}

	end, err := parseBound(form, "end_time", "end_utc")
	if err != nil {
		return timeWindow{}, errors.Join(errInvalidDates, err)
	}

	// Clearing a filter or following a cursor keeps these bounds and carries the preset for the next search.
	window := timeWindow{start: start, end: end}
	if hasCursor || form.Get("clear_message") == "1" {
		if preset := form.Get("search_window"); presetDuration(preset, maxRange) != 0 {
			window.recent = preset
		}
	}
	return window, nil
}

func windowOptions(maxRange, appliedRange time.Duration) ([]model.FilterOption, string) {
	options := make([]model.FilterOption, 0, len(presets))
	selected := strings.Empty
	for _, preset := range presets {
		if preset.duration <= maxRange {
			options = append(options, preset.option)
			if preset.duration == appliedRange {
				selected = preset.option.Value
			}
		}
	}

	if len(options) == 0 {
		options = append(options, model.FilterOption{Value: recentRange, Label: "logs.range_recent"})
		if appliedRange == maxRange {
			selected = recentRange
		}
	}
	return options, selected
}

func presetDuration(value string, maxRange time.Duration) time.Duration {
	if value == recentRange {
		return maxRange
	}

	for _, preset := range presets {
		if preset.option.Value == value && preset.duration <= maxRange {
			return preset.duration
		}
	}
	return 0
}

func recentWindow(value string, duration time.Duration) timeWindow {
	end := time.Now().UTC()
	start := end.Add(-duration.Duration())
	// The configured range can reach before the unsigned storage epoch.
	if epoch := time.Unix(0).UTC(); start.Before(epoch) {
		start = epoch
	}
	return timeWindow{start: start, end: end, recent: value}
}

func parseBound(form url.Values, exactKey, pickerKey string) (time.Time, error) {
	exactText := form.Get(exactKey)
	hasExact := !strings.IsEmpty(exactText)
	hasPicker := form.Has(pickerKey)
	if !hasExact && !hasPicker {
		return time.Time{}, storage.ErrInvalidQuery
	}

	var exactTime time.Time
	if hasExact {
		if err := exactTime.UnmarshalText([]byte(exactText)); err != nil {
			return time.Time{}, err
		}
	}
	if !hasPicker {
		return exactTime.UTC(), nil
	}

	pickerText := form.Get(pickerKey)
	// A native datetime-local control omits seconds when they are zero.
	if len(pickerText) == len("2006-01-02T15:04") {
		pickerText += ":00"
	}

	var pickerTime time.Time
	if err := pickerTime.UnmarshalText([]byte(pickerText + "Z")); err != nil {
		return time.Time{}, err
	}

	// Preserve fractional seconds when the picker still shows the saved second.
	if pickerTime.Equal(exactTime.Truncate(time.Second.Duration())) {
		return exactTime.UTC(), nil
	}
	return pickerTime, nil
}
