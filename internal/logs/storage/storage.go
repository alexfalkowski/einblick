package storage

import (
	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/database/sql"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-sync"
	collector "go.opentelemetry.io/proto/otlp/collector/logs/v1"
)

// ErrInvalidLog identifies protobuf content that cannot be represented by the
// pinned log schema. Transport callers must report a permanent input failure.
var ErrInvalidLog = errors.New("logs: invalid protobuf content")

const (
	archivePageSlots     = 1
	archiveActivitySlots = 1
)

// Repository provides log persistence and queries over the service-owned database.
type Repository interface {
	// Add atomically persists a complete export and returns the committed record
	// count, or zero and an error on failure. Duplicate exports add new records.
	// Empty exports are successful no-ops; failures never acknowledge stored data.
	Add(ctx context.Context, req *collector.ExportLogsServiceRequest) (int, error)

	// List returns a bounded latest-first page using event-time/ID keysets.
	// New arrivals behind the cursor can enter later pages; refresh to see those ahead.
	// Invalid input returns ErrInvalidQuery; cancellation/deadline errors remain inspectable.
	List(ctx context.Context, query Query) (*Page, error)

	// Activity counts all matching logs across the selected interval in one read.
	Activity(ctx context.Context, query Query) (*Activity, error)
}

// newRepository provides log persistence and queries over the service-owned database.
// The migrate package initializes the schema before the listeners start.
func newRepository(cfg *Config, db *sql.DB, pool *sync.BufferPool, objects archive.ObjectStore, queries statements) Repository {
	return &repository{
		config: cfg, db: db, pool: pool, store: objects, statements: queries,
		localQueries:   sync.NewSemaphore(1),
		archiveQueries: sync.NewSemaphore(archivePageSlots + archiveActivitySlots),
	}
}
