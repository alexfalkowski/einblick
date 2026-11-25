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

	// Export stages the next batch using today at midnight UTC. It returns
	// the batch ID when claimed and an empty ID when there is no work.
	Export(ctx context.Context, today time.Time) (string, error)

	// Publish reconciles or uploads one batch and reclaims its confirmed file.
	// It returns the batch ID after cleanup or when processing that batch fails.
	Publish(ctx context.Context) (string, error)

	// ReconcilePublication checks one recorded upload or retries pending cleanup.
	// It leaves absent remote objects pending for Publish and reports IDs as Publish does.
	ReconcilePublication(ctx context.Context) (string, error)

	// Evict releases one batch eligible for local eviction as of today in UTC.
	Evict(ctx context.Context, today time.Time) (string, error)
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
	if params.Config == nil {
		return nil
	}

	return &loggingService{
		Service: &service{
			batches:  params.Batches,
			eviction: params.Eviction,
			files:    params.Files,
			objects:  params.Objects,
		},
		logger: params.Logger,
	}
}

type service struct {
	batches  BatchRepository
	eviction EvictionRepository
	files    StagedFiles
	objects  ObjectStore
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

func (s *service) Export(ctx context.Context, today time.Time) (string, error) {
	// Leave today and yesterday local, and group supplements after their receipt day ends.
	batch, err := s.batches.Next(ctx, LocalWindowStart(today), today)
	if err != nil || strings.IsEmpty(batch.ID) {
		return batch.ID, err
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
