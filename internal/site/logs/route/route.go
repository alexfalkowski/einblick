package route

import (
	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/einblick/internal/site/logs/controller"
	"github.com/alexfalkowski/einblick/internal/site/logs/view"
	"github.com/alexfalkowski/go-service/v3/net/http/mvc"
)

// Register installs GET /logs for the full page and PUT /logs for partial updates.
// Both routes use the shared repository for query validation and execution.
func Register(server *mvc.Server, repo storage.Repository, cfg *storage.Config) {
	full, partial := view.NewLogs(server)
	fullError, partialError := view.NewQueryError(server)

	server.Get("/logs", controller.NewLogs(repo, cfg.MaxRange, full, fullError), mvc.WithRouteUnauthenticated())
	server.Put("/logs", controller.NewLogs(repo, cfg.MaxRange, partial, partialError), mvc.WithRouteUnauthenticated())
}
