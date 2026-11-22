package archive

import (
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/telemetry/logger"
	"github.com/alexfalkowski/go-service/v3/time"
	"github.com/alexfalkowski/go-signal/v2"
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

	// Publish reconciles or uploads one batch and reclaims its confirmed file.
	// It returns the batch ID after cleanup or when processing that batch fails.
	Publish(ctx context.Context) (string, error)

	// ReconcilePublication checks one recorded upload or retries pending cleanup.
	// It leaves absent remote objects pending for Publish and reports IDs as Publish does.
	ReconcilePublication(ctx context.Context) (string, error)

	// Evict releases one batch eligible for local eviction.
	Evict(ctx context.Context) (string, error)
}

// ServiceParams supplies the injected dependencies for archive export.
type ServiceParams struct {
	signal.In
	Config   *Config
	Batches  BatchRepository
	Eviction EvictionRepository
	Files    StagedFiles
	Objects  ObjectStore
	Logger   *logger.Logger
}

// NewService composes durable batch state, local staging, publication and diagnostics.
// A nil configuration disables archive export.
func NewService(params ServiceParams) Service {
	cfg := params.Config
	if cfg == nil {
		return nil
	}

	return &loggingService{
		Service: &service{
			batches:        params.Batches,
			eviction:       params.Eviction,
			files:          params.Files,
			objects:        params.Objects,
			batchBytes:     cfg.BatchSize.Bytes(),
			localRetention: cfg.LocalRetention,
		},
		logger: params.Logger,
	}
}

type service struct {
	batches        BatchRepository
	eviction       EvictionRepository
	files          StagedFiles
	objects        ObjectStore
	batchBytes     int64
	localRetention time.Duration
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

	return batch.ID, s.stage(ctx, batch)
}

func (s *service) stage(ctx context.Context, batch Batch) error {
	checksum, err := s.files.Stage(ctx, batch)
	if err != nil {
		return err
	}

	return s.batches.Complete(ctx, batch.ID, checksum)
}
