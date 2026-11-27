package route

import (
	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/einblick/internal/r2"
	"github.com/alexfalkowski/einblick/internal/site/logs/controller"
	"github.com/alexfalkowski/einblick/internal/site/logs/view"
	"github.com/alexfalkowski/einblick/internal/site/timerange"
	"github.com/alexfalkowski/go-service/v3/net/http/mvc"
)

// Register installs GET /logs for the full page and PUT /logs for partial updates.
// Both routes use the shared repository for query validation and execution.
func Register(server *mvc.Server, repo storage.Repository, cfg *storage.Config, archive *r2.Config) {
	full, partial := view.NewLogs(server)
	fullError, partialError := view.NewQueryError(server)
	limits := timerange.Limits{MaxRange: cfg.MaxRange}
	if archive != nil {
		limits.Lookback = archive.Retention
	}

	server.Get("/logs", controller.NewLogs(repo, limits, full, fullError), mvc.WithRouteUnauthenticated())
	server.Put("/logs", controller.NewLogs(repo, limits, partial, partialError), mvc.WithRouteUnauthenticated())
	activity := server.NewPartialView("logs/view/activity.tmpl")
	server.Get("/logs/activity", controller.NewActivity(repo, limits, activity, partialError), mvc.WithRouteUnauthenticated())
}
