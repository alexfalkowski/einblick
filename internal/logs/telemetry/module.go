// Package telemetry instruments log ingestion, searches and archive publication.
package telemetry

import (
	"context"

	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/go-service/v3/telemetry/logger"
	"github.com/alexfalkowski/go-service/v3/telemetry/metrics"
	"github.com/alexfalkowski/go-signal/v2"
)

// Module decorates the log repository and registers archive backlog metrics.
var Module = signal.Module(
	signal.Decorate(decorateRepository),
	signal.Register(Register),
)

// RegisterParams supplies the dependencies for archive backlog metrics.
type RegisterParams struct {
	signal.In
	Lifecycle signal.Lifecycle
	Meter     metrics.Meter
	Objects   archive.ObjectStore
	Archive   *storage.Archive
	Config    *archive.Config
	Queries   *storage.Config
	Logger    *logger.Logger
}

// Register attaches archive backlog metrics to the service lifecycle when R2 is configured.
func Register(params RegisterParams) {
	if params.Objects == nil || !metrics.IsEnabled() {
		return
	}

	var stop func(context.Context) error
	params.Lifecycle.Append(signal.Hook{
		OnStart: func(ctx context.Context) error {
			var err error
			stop, err = startBacklogMetrics(ctx, params)
			return err
		},
		OnStop: func(ctx context.Context) error { return stop(ctx) },
	})
}
