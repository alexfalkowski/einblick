package storage

import (
	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/database/sql"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/time"
)

// NextEviction records an attempt on the longest-waiting confirmed and cleaned
// batch whose UTC event day predates eventBefore.
// A zero value indicates no eligible batch.
func (r *Archive) NextEviction(ctx context.Context, eventBefore time.Time) (archive.Publication, error) {
	statement := r.statements.MustLookup("queries/archive/next_eviction.sql")

	var batch archive.Publication
	row := r.db.QueryRowContext(ctx, statement, eventBefore.Format(archive.DayLayout))
	err := row.Scan(&batch.ID, &batch.Day, &batch.PublishedChecksum)
	if errors.Is(err, sql.ErrNoRows) {
		return archive.Publication{}, nil
	}
	return batch, err
}

// Evict removes a confirmed batch and its unused OTLP headers after the worker
// checks its object. Retained batch state identifies the remote query source.
func (r *Archive) Evict(ctx context.Context, id string, storedAt time.Time) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	for _, path := range []string{
		"queries/archive/evict_resources.sql",
		"queries/archive/evict_scopes.sql",
		"queries/archive/evict_logs.sql",
		"queries/archive/evict_members.sql",
	} {
		statement := r.statements.MustLookup(path)
		if _, err := tx.ExecContext(ctx, statement, id); err != nil {
			return err
		}
	}

	markEvicted := r.statements.MustLookup("queries/archive/mark_evicted.sql")
	objectStoredAt := sql.NullTime{Time: storedAt.UTC(), Valid: !storedAt.IsZero()}
	if _, err := tx.ExecContext(ctx, markEvicted, objectStoredAt, id); err != nil {
		return err
	}
	return tx.Commit()
}
