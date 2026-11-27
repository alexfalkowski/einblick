package controller

import (
	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/einblick/internal/site/logs/model"
	"github.com/alexfalkowski/einblick/internal/site/logs/query"
	"github.com/alexfalkowski/einblick/internal/site/timerange"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/net/http/meta"
	"github.com/alexfalkowski/go-service/v3/net/http/mvc"
	"github.com/alexfalkowski/go-service/v3/time"
)

// NewActivity serves a localized summary of the applied log search.
func NewActivity(repo storage.Repository, limits timerange.Limits, view, errorView *mvc.View) mvc.Controller[model.Activity] {
	return func(ctx context.Context) (*mvc.View, *model.Activity, error) {
		req, res := meta.Request(ctx), meta.Response(ctx)
		res.Header().Set("Cache-Control", "no-store")
		res.Header().Set("Einblick-View", "logs-activity")

		if err := req.ParseForm(); err != nil {
			return errorView, nil, queryError(req, errors.Join(storage.ErrInvalidQuery, err))
		}

		search, err := query.Parse(req.Form, time.Now(), limits)
		if err != nil {
			return errorView, nil, queryError(req, err)
		}

		activity, err := repo.Activity(ctx, search.Query())
		if err != nil {
			if errors.Is(err, storage.ErrActivityBusy) {
				res.Header().Set("Einblick-Activity", "busy")
			}
			return errorView, nil, queryError(req, err)
		}

		return view, model.NewActivity(activity), nil
	}
}
