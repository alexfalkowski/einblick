package storage

import (
	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/database/sql"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/time"
)

// NextEviction records an attempt on the longest-waiting eligible batch.
// A zero value indicates no eligible batch.
func (r *Archive) NextEviction(ctx context.Context, cutoff time.Time) (archive.Publication, error) {
	var batch archive.Publication
	row := r.db.QueryRowContext(ctx, nextEvictionQuery, unixNanoseconds(cutoff).String())
	err := row.Scan(&batch.ID, &batch.Day, &batch.PublishedChecksum)
	if errors.Is(err, sql.ErrNoRows) {
		return archive.Publication{}, nil
	}
	return batch, err
}

// Evict removes a confirmed batch and its unused OTLP headers after the worker
// checks its object. Retained batch state identifies the remote query source.
func (r *Archive) Evict(ctx context.Context, id string) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	for _, statement := range []string{evictResourcesQuery, evictScopesQuery, evictLogsQuery, evictMembersQuery, markEvictedQuery} {
		if _, err := tx.ExecContext(ctx, statement, id); err != nil {
			return err
		}
	}
	return tx.Commit()
}
