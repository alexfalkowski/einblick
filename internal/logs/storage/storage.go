package storage

import (
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/database/sql"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/telemetry/logger"
	"github.com/alexfalkowski/go-sync"
	collector "go.opentelemetry.io/proto/otlp/collector/logs/v1"
)

// ErrInvalidLog identifies protobuf content that cannot be represented by the
// pinned log schema. Transport callers must report a permanent input failure.
var ErrInvalidLog = errors.New("logs: invalid protobuf content")

// Repository provides local log persistence. NewRepository composes diagnostic
// logging without taking ownership of the database lifecycle.
type Repository interface {
	// Add atomically persists a complete export and returns the committed record
	// count, or zero and an error on failure. Duplicate exports add new records.
	// Empty exports are successful no-ops; failures never acknowledge stored data.
	Add(ctx context.Context, req *collector.ExportLogsServiceRequest) (int, error)
}

// NewRepository composes log persistence and diagnostic logging over the service-owned database.
// The migrate package initializes the schema before the listeners start.
//
//nolint:ireturn // The constructor provides the composed Repository interface.
func NewRepository(db *sql.DB, pool *sync.BufferPool, log *logger.Logger) Repository {
	return &loggingRepository{Repository: &repository{db: db, pool: pool}, logger: log}
}
