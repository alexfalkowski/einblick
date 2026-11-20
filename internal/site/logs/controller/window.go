package controller

import (
	"net/url"

	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/einblick/internal/site/logs/model"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
)

const (
	quarterHour = 15 * time.Minute
	day         = 24 * time.Hour
)

type timePreset struct {
	option   model.FilterOption
	duration time.Duration
}

type timeWindow struct {
	start time.Time
	end   time.Time
}

var presets = []timePreset{
	{option: model.FilterOption{Value: "15m", Label: "logs.last_15_minutes"}, duration: quarterHour},
	{option: model.FilterOption{Value: "1h", Label: "logs.last_hour"}, duration: time.Hour},
	{option: model.FilterOption{Value: "24h", Label: "logs.last_24_hours"}, duration: day},
}

func resolveWindow(form url.Values, maxRange time.Duration) (timeWindow, error) {
	hasCursor := !strings.IsEmpty(form.Get("page_token"))
	if preset := form.Get("window"); !strings.IsEmpty(preset) {
		if hasCursor {
			return timeWindow{}, storage.ErrInvalidQuery
		}
		return resolvePreset(preset, maxRange)
	}

	hasBounds := form.Has("start_time") || form.Has("end_time") || form.Has("start_utc") || form.Has("end_utc")
	if !hasBounds && !hasCursor {
		return recentWindow(maxRange), nil
	}

	start, err := parseBound(form, "start_time", "start_utc")
	if err != nil {
		return timeWindow{}, err
	}

	end, err := parseBound(form, "end_time", "end_utc")
	return timeWindow{start: start, end: end}, err
}

func windowOptions(maxRange time.Duration) []model.FilterOption {
	options := make([]model.FilterOption, 0, len(presets))
	for _, preset := range presets {
		if preset.duration <= maxRange {
			options = append(options, preset.option)
		}
	}
	return options
}

func resolvePreset(value string, maxRange time.Duration) (timeWindow, error) {
	for _, preset := range presets {
		if preset.option.Value == value && preset.duration <= maxRange {
			return recentWindow(preset.duration), nil
		}
	}
	return timeWindow{}, storage.ErrInvalidQuery
}

func recentWindow(duration time.Duration) timeWindow {
	end := time.Now().UTC()
	start := end.Add(-duration.Duration())
	// The configured range can reach before the unsigned storage epoch.
	if epoch := time.Unix(0).UTC(); start.Before(epoch) {
		start = epoch
	}
	return timeWindow{start: start, end: end}
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
