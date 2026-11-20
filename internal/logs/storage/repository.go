package storage

import (
	"strconv"

	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/database/sql"
	"github.com/alexfalkowski/go-service/v3/encoding/proto"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
	"github.com/alexfalkowski/go-sync"
	collector "go.opentelemetry.io/proto/otlp/collector/logs/v1"
	logs "go.opentelemetry.io/proto/otlp/logs/v1"
)

// repository writes one atomic transaction per nonempty OTLP export. It owns no
// background queue, extra connection pool, retries or independent lifecycle.
type repository struct {
	config  *Config
	db      *sql.DB
	pool    *sync.BufferPool
	queries *sync.Semaphore
}

// Add commits all records and their resource/scope context before returning
// their count. Empty requests are successful no-ops. Any encoding, statement or
// commit failure returns zero and an error; accepted rows are never evicted here.
// Duplicate exports create additional records. The request context bounds SQL
// work, and the shared transport owns admission size/rate/deadline limits.
func (r *repository) Add(ctx context.Context, req *collector.ExportLogsServiceRequest) (int, error) {
	received := time.Now().UnixNano()

	count := 0
	for _, resource := range req.GetResourceLogs() {
		count += recordCount(resource)
	}
	if count == 0 {
		return 0, nil
	}

	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()

	for _, resource := range req.GetResourceLogs() {
		if recordCount(resource) == 0 {
			continue
		}

		header := &logs.ResourceLogs{Resource: resource.GetResource(), SchemaUrl: resource.GetSchemaUrl()}
		resourceID, err := r.insertHeader(ctx, tx, insertResourceQuery, header)
		if err != nil {
			return 0, err
		}

		for _, scope := range resource.GetScopeLogs() {
			if err := r.writeScope(ctx, tx, scope, resourceID, received); err != nil {
				return 0, err
			}
		}
	}

	if err := tx.Commit(); err != nil {
		return 0, errors.Prefix("logs: commit", err)
	}
	return count, nil
}

func (r *repository) writeScope(ctx context.Context, tx *sql.Tx, scope *logs.ScopeLogs, resourceID, received int64) error {
	if len(scope.GetLogRecords()) == 0 {
		return nil
	}

	header := &logs.ScopeLogs{Scope: scope.GetScope(), SchemaUrl: scope.GetSchemaUrl()}
	scopeID, err := r.insertHeader(ctx, tx, insertScopeQuery, header, resourceID)
	if err != nil {
		return err
	}

	for _, record := range scope.GetLogRecords() {
		content, err := r.encode(record)
		if err != nil {
			return err
		}

		// Decimal binding avoids database/sql's signed conversion of uint64
		// through instrumented statements. DuckDB stores exact UBIGINTs.
		timestamp := strconv.FormatUint(record.GetTimeUnixNano(), 10)
		observed := strconv.FormatUint(record.GetObservedTimeUnixNano(), 10)

		_, err = tx.ExecContext(ctx, insertLogQuery, scopeID, timestamp, observed, received, timestamp, observed, received, content)
		if err != nil {
			return err
		}
	}
	return nil
}

func (r *repository) insertHeader(ctx context.Context, tx *sql.Tx, query string, header proto.Message, args ...any) (int64, error) {
	content, err := r.encode(header)
	if err != nil {
		return 0, err
	}

	args = append(args, content)

	var id int64
	err = tx.QueryRowContext(ctx, query, args...).Scan(&id)
	return id, err
}

func (r *repository) encode(message proto.Message) (string, error) {
	content := r.pool.Get()
	defer r.pool.Put(content)

	if err := proto.NewJSON().Encode(content, message); err != nil {
		return strings.Empty, errors.Join(ErrInvalidLog, err)
	}
	return content.String(), nil
}

func recordCount(resource *logs.ResourceLogs) int {
	count := 0
	for _, scope := range resource.GetScopeLogs() {
		count += len(scope.GetLogRecords())
	}
	return count
}
