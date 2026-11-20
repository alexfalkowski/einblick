package controller

import (
	"net/url"
	"strconv"

	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/net/http"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
)

// Query bounds retain nanoseconds in the form and pagination URLs.
const queryTimeLayout = "2006-01-02T15:04:05.999999999Z07:00"

func parseQuery(req *http.Request, maxRange time.Duration) (storage.Query, error) {
	if err := req.ParseForm(); err != nil {
		return storage.Query{}, errors.Join(storage.ErrInvalidQuery, err)
	}

	form := req.Form
	query := storage.Query{
		Service: form.Get("service"), Severity: form.Get("severity"),
		Text: form.Get("text"), TraceID: form.Get("trace_id"), PageToken: form.Get("page_token"),
	}
	if size := form.Get("page_size"); !strings.IsEmpty(size) {
		var err error
		if query.PageSize, err = strconv.Atoi(size); err != nil {
			return storage.Query{}, errors.Join(storage.ErrInvalidQuery, err)
		}
	}

	window, err := resolveWindow(form, maxRange)
	if err != nil {
		return storage.Query{}, errors.Join(storage.ErrInvalidQuery, err)
	}
	query.StartTime, query.EndTime = window.start, window.end

	return query, nil
}

func logsURL(query storage.Query) string {
	values := url.Values{
		"start_time": {query.StartTime.Format(queryTimeLayout)},
		"end_time":   {query.EndTime.Format(queryTimeLayout)},
	}
	optionalValues := map[string]string{
		"service":    query.Service,
		"severity":   query.Severity,
		"text":       query.Text,
		"trace_id":   query.TraceID,
		"page_token": query.PageToken,
	}

	for name, value := range optionalValues {
		if !strings.IsEmpty(value) {
			values.Set(name, value)
		}
	}
	if query.PageSize != 0 {
		values.Set("page_size", strconv.Itoa(query.PageSize))
	}

	return "/logs?" + values.Encode()
}
