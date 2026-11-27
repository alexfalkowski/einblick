package controller

import (
	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/einblick/internal/site/logs/model"
	"github.com/alexfalkowski/einblick/internal/site/logs/query"
	"github.com/alexfalkowski/einblick/internal/site/timerange"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/net/http"
	"github.com/alexfalkowski/go-service/v3/net/http/meta"
	"github.com/alexfalkowski/go-service/v3/net/http/mvc"
	"github.com/alexfalkowski/go-service/v3/time"
)

// NewLogs queries the log repository and prepares a model for the supplied
// full or partial view. The error view renders localized request failures.
func NewLogs(repo storage.Repository, limits timerange.Limits, view, errorView *mvc.View) mvc.Controller[model.Logs] {
	return func(ctx context.Context) (*mvc.View, *model.Logs, error) {
		req, res := meta.Request(ctx), meta.Response(ctx)
		res.Header().Set("Cache-Control", "no-store")
		partial := req.Method == http.MethodPut
		if partial {
			res.Header().Set("Einblick-View", "logs-results")
		}

		if err := req.ParseForm(); err != nil {
			return errorView, nil, queryError(req, errors.Join(storage.ErrInvalidQuery, err))
		}
		now := time.Now().UTC()
		search, err := query.Parse(req.Form, now, limits)
		if err != nil {
			return errorView, nil, queryError(req, err)
		}

		result, err := repo.List(ctx, search.Query())
		if err != nil {
			return errorView, nil, queryError(req, err)
		}

		viewModel, err := model.NewLogs(ctx, search, result, now, limits)
		if err != nil {
			return errorView, nil, queryError(req, err)
		}

		if partial && req.Header.Get("Hx-Request") == "true" {
			res.Header().Set("Hx-Push-Url", viewModel.QueryURL)
		}

		return view, viewModel, nil
	}
}
