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
	s.logBatchOutcome(ctx, "local log archive export", id, err)
	return id, err
}

func (s *loggingService) Publish(ctx context.Context) (string, error) {
	id, err := s.Service.Publish(ctx)
	s.logBatchOutcome(ctx, "remote log archive publication", id, err)
	return id, err
}

func (s *loggingService) ReconcilePublication(ctx context.Context) (string, error) {
	id, err := s.Service.ReconcilePublication(ctx)
	s.logBatchOutcome(ctx, "remote log archive publication", id, err)
	return id, err
}

func (s *loggingService) Evict(ctx context.Context) (string, error) {
	id, err := s.Service.Evict(ctx)
	s.logBatchOutcome(ctx, "local log archive eviction", id, err)
	return id, err
}

func (s *loggingService) logBatchOutcome(ctx context.Context, operation, id string, err error) {
	var message logger.Message
	switch {
	case err != nil && ctx.Err() == nil:
		message = logger.NewMessage(strings.Concat(operation, " failed"), err)
	case err == nil && !strings.IsEmpty(id):
		message = logger.NewText(strings.Concat(operation, " completed"))
	default:
		return
	}

	s.logger.Log(ctx, message,
		logger.String("component", "log_archive"),
		logger.String("batch_id", id),
	)
}
