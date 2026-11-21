package archive

import (
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/telemetry/logger"
)

type loggingService struct {
	Service
	logger *logger.Logger
}

func (s *loggingService) Recover(ctx context.Context) error {
	err := s.Service.Recover(ctx)
	if err != nil && ctx.Err() == nil {
		s.logger.Log(ctx, logger.NewMessage("local log archive recovery failed", err), logger.String("component", "log_archive"))
	}
	return err
}

func (s *loggingService) Export(ctx context.Context) (string, error) {
	id, err := s.Service.Export(ctx)

	var message logger.Message
	switch {
	case err != nil && ctx.Err() == nil:
		message = logger.NewMessage("local log archive export failed", err)
	case err == nil && !strings.IsEmpty(id):
		message = logger.NewText("local log archive export completed")
	default:
		return id, err
	}

	s.logger.Log(ctx, message,
		logger.String("component", "log_archive"),
		logger.String("batch_id", id),
	)
	return id, err
}
