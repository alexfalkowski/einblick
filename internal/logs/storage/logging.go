package storage

import (
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/telemetry/logger"
	v1 "go.opentelemetry.io/proto/otlp/collector/logs/v1"
)

type loggingRepository struct {
	Repository
	logger *logger.Logger
}

func (r *loggingRepository) Add(ctx context.Context, req *v1.ExportLogsServiceRequest) (int, error) {
	count, err := r.Repository.Add(ctx, req)
	if err != nil {
		r.logger.Log(ctx, logger.NewMessage("log export failed", err), logger.String("component", "logs"))
		return count, err
	}

	r.logger.Log(ctx, logger.NewText("log export committed"), logger.String("component", "logs"), logger.Int("records", count))
	return count, nil
}
