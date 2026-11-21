package archive

import (
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/telemetry/logger"
)

// Service recovers recorded batches and stages one batch per export attempt.
type Service interface {
	// Prepare checks the workspace and clears interrupted temporary output.
	Prepare() error

	// Recover verifies completed files and requeues absent or damaged files.
	Recover(ctx context.Context) error

	// Export stages the next batch and records completion. It returns the batch
	// ID when claimed and an empty ID when there is no work.
	Export(ctx context.Context) (string, error)
}

// NewService composes durable batch state, local file staging, and export diagnostics.
// A nil cfg disables archive export.
func NewService(cfg *Config, batches BatchRepository, files StagedFiles, log *logger.Logger) Service {
	if cfg == nil {
		return nil
	}

	return &loggingService{
		Service: &service{batches: batches, files: files, batchBytes: cfg.BatchSize.Bytes()},
		logger:  log,
	}
}

type service struct {
	batches    BatchRepository
	files      StagedFiles
	batchBytes int64
}

func (s *service) Prepare() error {
	return s.files.Prepare()
}

func (s *service) Recover(ctx context.Context) error {
	return s.batches.VisitCompleted(ctx, func(batch StagedBatch) error {
		valid, err := s.files.Verify(ctx, batch)
		if err != nil || valid {
			return err
		}

		return s.batches.Requeue(ctx, batch.ID)
	})
}

func (s *service) Export(ctx context.Context) (string, error) {
	batch, err := s.batches.Next(ctx, s.batchBytes)
	if err != nil || strings.IsEmpty(batch.ID) {
		return strings.Empty, err
	}

	checksum, err := s.files.Stage(ctx, batch)
	if err != nil {
		return batch.ID, err
	}

	return batch.ID, s.batches.Complete(ctx, batch.ID, checksum)
}
