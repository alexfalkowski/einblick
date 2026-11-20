package storage

import (
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/telemetry/logger"
	"github.com/alexfalkowski/go-service/v3/time"
	v1 "go.opentelemetry.io/proto/otlp/collector/logs/v1"
)

type loggingRepository struct {
	Repository
	logger *logger.Logger
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

func (r *loggingRepository) List(ctx context.Context, query Query) (*Page, error) {
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
