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

		query, err := parseQuery(req, maxRange)
		if err != nil {
			return errorView, nil, queryError(err)
		}

		result, err := repo.List(ctx, query)
		if err != nil {
			return errorView, nil, queryError(err)
		}

		viewModel, err := newLogsModel(ctx, query, result, maxRange)
		if err != nil {
			return errorView, nil, queryError(err)
		}

		if partial && req.Header.Get("Hx-Request") == "true" {
			res.Header().Set("Hx-Push-Url", viewModel.QueryURL)
		}

		return view, viewModel, nil
	}
}

func queryError(err error) error {
	switch {
	case errors.Is(err, storage.ErrInvalidQuery):
		return status.BadRequestError(err)
	case errors.Is(err, context.Canceled), errors.Is(err, context.DeadlineExceeded):
		return err
	default:
		return status.ServiceUnavailableError(err)
	}
}
