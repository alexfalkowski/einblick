package controller

import (
	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/einblick/internal/site/timerange"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/net/http"
	"github.com/alexfalkowski/go-service/v3/net/http/status"
	"github.com/alexfalkowski/go-service/v3/strings"
)

func queryError(req *http.Request, err error) error {
	switch {
	case errors.Is(err, storage.ErrInvalidQuery):
		if badRequest := status.BadRequestError(err); status.Code(badRequest) != http.StatusBadRequest {
			return badRequest
		}
		return errors.Join(status.Error(http.StatusBadRequest, invalidQueryLabel(req, err)), err)
	case errors.Is(err, context.Canceled), errors.Is(err, context.DeadlineExceeded):
		return err
	default:
		return status.ServiceUnavailableError(err)
	}
}

func invalidQueryLabel(req *http.Request, err error) string {
	form := req.Form
	hasDates := form.Has("start_utc") || form.Has("end_utc")
	isLink := !strings.IsEmpty(form.Get("page_token")) || (req.Method == http.MethodGet && !hasDates)
	switch {
	case errors.Is(err, timerange.ErrOutsideLookback):
		return "logs.date_outside_history"
	case isLink:
		return "logs.invalid_link"
	case errors.Is(err, storage.ErrTimeOrder):
		return "logs.date_order"
	case errors.Is(err, storage.ErrTimeRangeTooWide):
		return "logs.date_range_too_wide"
	case errors.Is(err, storage.ErrTimeBounds), errors.Is(err, timerange.ErrInvalidDates):
		return "logs.invalid_dates"
	default:
		return "logs.invalid_filters"
	}
}
