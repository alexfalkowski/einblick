package controller

import (
	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/einblick/internal/site/logs/model"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/net/http"
	"github.com/alexfalkowski/go-service/v3/net/http/meta"
	"github.com/alexfalkowski/go-service/v3/net/http/mvc"
	"github.com/alexfalkowski/go-service/v3/net/http/status"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
)

// NewLogs queries the local log repository and assembles a model for the supplied
// full or partial view. The error view renders localized request failures.
func NewLogs(repo storage.Repository, maxRange time.Duration, view, errorView *mvc.View) mvc.Controller[model.Logs] {
	return func(ctx context.Context) (*mvc.View, *model.Logs, error) {
		req, res := meta.Request(ctx), meta.Response(ctx)
		res.Header().Set("Cache-Control", "no-store")
		partial := req.Method == http.MethodPut
		if partial {
			res.Header().Set("Einblick-View", "logs-results")
		}

		query, recent, err := parseQuery(req, maxRange)
		if err != nil {
			return errorView, nil, queryError(req, err)
		}

		result, err := repo.List(ctx, query)
		if err != nil {
			return errorView, nil, queryError(req, err)
		}

		viewModel, err := newLogsModel(ctx, query, result, recent, maxRange)
		if err != nil {
			return errorView, nil, queryError(req, err)
		}

		if partial && req.Header.Get("Hx-Request") == "true" {
			res.Header().Set("Hx-Push-Url", viewModel.QueryURL)
		}

		return view, viewModel, nil
	}
}

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
	case isLink:
		return "logs.invalid_link"
	case errors.Is(err, storage.ErrTimeOrder):
		return "logs.date_order"
	case errors.Is(err, storage.ErrTimeRangeTooWide):
		return "logs.date_range_too_wide"
	case errors.Is(err, storage.ErrTimeBounds), errors.Is(err, errInvalidDates):
		return "logs.invalid_dates"
	default:
		return "logs.invalid_filters"
	}
}
