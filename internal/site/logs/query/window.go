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
	case !hasWindow && submittedDates(form):
		return pickerSelection(form)
	case hasCursor && !form.Has("start_time") && !form.Has("end_time"):
		return timerange.Selection{}, timerange.ErrInvalidDates
	default:
		return timerange.Resolve(form, now, maxRange)
	}
}

func customSelection(form url.Values, selection timerange.Selection, now time.Time, limits timerange.Limits) (bool, error) {
	if !strings.IsEmpty(form.Get("window")) {
		return false, nil
	}

	if !submittedDates(form) {
		// Chart selections, saved links and filter clearing keep the applied bounds.
		if form.Get("custom") != "1" {
			return false, nil
		}
		if !form.Has("start_time") {
			return false, timerange.ErrInvalidDates
		}
		return true, nil
	}

	if keepsAppliedDates(form, selection) {
		return true, nil
	}

	earliest := limits.Earliest(now).Truncate(time.Second.Duration())
	if selection.StartTime.Before(earliest) {
		return false, timerange.ErrOutsideLookback
	}
	if selection.EndTime.After(now) {
		return false, timerange.ErrInvalidDates
	}
	return true, nil
}

func keepsAppliedDates(form url.Values, selection timerange.Selection) bool {
	return form.Get("custom") == "1" &&
		selection.StartTime.Format(time.RFC3339Nano) == form.Get("start_time") &&
		selection.EndTime.Format(time.RFC3339Nano) == form.Get("end_time")
}

func submittedDates(form url.Values) bool {
	return form.Get("clear_message") != "1" && (form.Has("start_utc") || form.Has("end_utc"))
}

func pickerSelection(form url.Values) (timerange.Selection, error) {
	mode := form.Get("custom")
	if mode != "picker" && mode != "1" {
		return timerange.Selection{}, timerange.ErrInvalidDates
	}

	start, err := parsePickerBound(form.Get("start_time"), form.Get("start_utc"))
	if err != nil {
		return timerange.Selection{}, errors.Join(timerange.ErrInvalidDates, err)
	}

	end, err := parsePickerBound(form.Get("end_time"), form.Get("end_utc"))
	if err != nil {
		return timerange.Selection{}, errors.Join(timerange.ErrInvalidDates, err)
	}

	return timerange.Selection{StartTime: start, EndTime: end}, nil
}

func parsePickerBound(exactText, pickerText string) (time.Time, error) {
	var exactTime time.Time
	if err := exactTime.UnmarshalText([]byte(exactText)); err != nil {
		return time.Time{}, err
	}

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
