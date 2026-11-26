package query

import (
	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/einblick/internal/site/timerange"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/net/url"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
)

func resolveTime(form url.Values, token string, now time.Time, maxRange time.Duration) (timerange.Selection, error) {
	hasWindow := !strings.IsEmpty(form.Get("window"))
	hasCursor := !strings.IsEmpty(token)
	switch {
	case hasWindow && hasCursor:
		return timerange.Selection{}, storage.ErrInvalidQuery
	case !hasWindow && (form.Has("start_utc") || form.Has("end_utc")):
		return legacySelection(form)
	case hasCursor && !form.Has("start_time") && !form.Has("end_time"):
		return timerange.Selection{}, timerange.ErrInvalidDates
	default:
		return timerange.Resolve(form, now, maxRange)
	}
}

func legacySelection(form url.Values) (timerange.Selection, error) {
	start, err := parseLegacyBound(form, "start_time", "start_utc")
	if err != nil {
		return timerange.Selection{}, errors.Join(timerange.ErrInvalidDates, err)
	}
	end, err := parseLegacyBound(form, "end_time", "end_utc")
	if err != nil {
		return timerange.Selection{}, errors.Join(timerange.ErrInvalidDates, err)
	}
	return timerange.Selection{StartTime: start, EndTime: end}, nil
}

func parseLegacyBound(form url.Values, exactKey, pickerKey string) (time.Time, error) {
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
