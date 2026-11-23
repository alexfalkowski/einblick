package telemetry

import (
	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/telemetry/logger"
	"github.com/alexfalkowski/go-service/v3/time"
	v1 "go.opentelemetry.io/proto/otlp/collector/logs/v1"
)

func logBacklog(read func(context.Context) (archive.Backlog, error), log *logger.Logger) func(context.Context) (archive.Backlog, error) {
	return func(ctx context.Context) (archive.Backlog, error) {
		started := time.Now()
		backlog, err := read(ctx)
		if err != nil && !errors.Is(ctx.Err(), context.Canceled) {
			log.Log(ctx, logger.NewMessage("log archive backlog collection failed", err),
				logger.String("component", "log_archive"),
				logger.String("started_at", started.UTC().Format("2006-01-02T15:04:05.999999999Z07:00")),
			)
		}
		return backlog, err
	}
}

type loggingRepository struct {
	storage.Repository
	logger *logger.Logger
}

func decorateRepository(repo storage.Repository, log *logger.Logger) storage.Repository {
	return &loggingRepository{Repository: repo, logger: log}
}

func (r *loggingRepository) Add(ctx context.Context, req *v1.ExportLogsServiceRequest) (int, error) {
	count, err := r.Repository.Add(ctx, req)
	if err != nil {
		r.logger.Log(ctx, logger.NewMessage("log export failed", err),
			logger.String("component", "logs"),
		)
		return count, err
	}

	r.logger.Log(ctx, logger.NewText("log export committed"),
		logger.String("component", "logs"),
		logger.Int("records", count),
	)
	return count, nil
}

func (r *loggingRepository) List(ctx context.Context, query storage.Query) (*storage.Page, error) {
	started := time.Now()
	page, err := r.Repository.List(ctx, query)
	if err != nil {
		r.logger.Log(ctx, logger.NewMessage("log query failed", err),
			logger.String("component", "logs"),
		)
		return page, err
	}

	r.logger.Log(ctx, logger.NewText("log query completed"),
		logger.String("component", "logs"),
		logger.Int("records", len(page.Logs)),
		logger.String("duration", time.Since(started).String()),
	)
	return page, nil
}
