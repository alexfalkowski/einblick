package query

import (
	"strconv"

	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/einblick/internal/site/timerange"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/net/url"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
)

// Search pairs the repository query with the time selection shown in the browser.
type Search struct {
	// Time describes the applied bounds and the browser's next search window.
	Time timerange.Selection

	filters storage.Query
}

// Parse binds the Logs form and resolves its time selection against now.
func Parse(form url.Values, now time.Time, maxRange time.Duration) (Search, error) {
	filters := storage.Query{
		Service: form.Get("service"), Severity: form.Get("severity"),
		Text: form.Get("text"), TraceID: form.Get("trace_id"), PageToken: form.Get("page_token"),
	}
	if form.Get("clear_message") == "1" {
		filters.Text = strings.Empty
	}
	if size := form.Get("page_size"); !strings.IsEmpty(size) {
		var err error
		if filters.PageSize, err = strconv.Atoi(size); err != nil {
			return Search{}, errors.Join(storage.ErrInvalidQuery, err)
		}
	}

	selection, err := resolveTime(form, filters.PageToken, now, maxRange)
	if err != nil {
		return Search{}, errors.Join(storage.ErrInvalidQuery, err)
	}
	// Pagination and filter clearing carry the preset for a fresh search.
	if preset := form.Get("search_window"); strings.IsEmpty(selection.SearchWindow) && timerange.Duration(preset, maxRange) != 0 {
		selection.SearchWindow = preset
	}
	return Search{Time: selection, filters: filters}, nil
}

// Query returns the repository request with the applied filters and exact bounds.
func (s Search) Query() storage.Query {
	filters := s.filters
	filters.StartTime, filters.EndTime = s.Time.StartTime, s.Time.EndTime
	return filters
}

// ReloadURL opens a fresh rolling search with the applied filters.
func (s Search) ReloadURL(maxRange time.Duration) string {
	values := s.filterValues()
	values.Set("window", s.Time.ReloadWindow(maxRange))
	return "/logs?" + values.Encode()
}

// NextURL continues the current date range and filters with the repository's token.
// It returns an empty URL at exhaustion.
func (s Search) NextURL(token string) string {
	if strings.IsEmpty(token) {
		return strings.Empty
	}
	values := s.snapshotValues()
	values.Set("page_token", token)
	if !strings.IsEmpty(s.Time.SearchWindow) {
		values.Set("search_window", s.Time.SearchWindow)
	}
	return "/logs?" + values.Encode()
}

// RelatedLogsURL searches the applied bounds with the row's trace ID. It returns
// an empty URL when the row has no usable trace ID.
func (s Search) RelatedLogsURL(traceID string) string {
	if !storage.ValidTraceID(traceID) {
		return strings.Empty
	}
	values := s.snapshotValues()
	values.Set("trace_id", traceID)
	return "/logs?" + values.Encode()
}

func (s Search) snapshotValues() url.Values {
	values := s.filterValues()
	values.Set("start_time", s.Time.StartTime.Format(time.RFC3339Nano))
	values.Set("end_time", s.Time.EndTime.Format(time.RFC3339Nano))
	return values
}

func (s Search) filterValues() url.Values {
	values := url.Values{}
	optionalValues := map[string]string{
		"service":  s.filters.Service,
		"severity": s.filters.Severity,
		"text":     s.filters.Text,
		"trace_id": s.filters.TraceID,
	}

	for name, value := range optionalValues {
		if !strings.IsEmpty(value) {
			values.Set(name, value)
		}
	}
	if s.filters.PageSize != 0 {
		values.Set("page_size", strconv.Itoa(s.filters.PageSize))
	}

	return values
}
