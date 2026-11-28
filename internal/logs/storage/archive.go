package storage

import (
	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/database/sql"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
)

// newArchive provides durable batch state and Parquet exports backed by DuckDB.
func newArchive(db *sql.DB, queries statements) *Archive {
	return &Archive{db: db, statements: queries}
}

// Archive owns durable log batch state and Parquet content verification.
type Archive struct {
	db         *sql.DB
	statements statements
}

// Next selects the earliest work and advances the attempted batch to the end
// of the staging queue. The worker calls Next serially.
func (r *Archive) Next(ctx context.Context, eventBefore, receiptBefore time.Time) (archive.Batch, error) {
	nextBatch := r.statements.MustLookup("queries/archive/next_batch.sql")

	var pending archive.Batch
	var order sql.Null[int64]
	err := r.db.QueryRowContext(ctx, nextBatch).Scan(&pending.ID, &pending.Day, &pending.ContentDigest, &order)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return archive.Batch{}, err
	}

	// Staging positions share the log ID sequence, so already waiting log rows
	// can take precedence over a retry without starving it behind new arrivals.
	claimed, err := r.create(ctx, eventBefore, receiptBefore, order)
	if err != nil {
		return claimed, err
	}
	if !strings.IsEmpty(claimed.ID) {
		return r.seal(ctx, claimed)
	}
	if strings.IsEmpty(pending.ID) {
		return pending, nil
	}

	rotateStaging := r.statements.MustLookup("queries/archive/rotate_staging.sql")

	if _, err := r.db.ExecContext(ctx, rotateStaging, pending.ID); err != nil {
		return pending, err
	}
	return r.seal(ctx, pending)
}

func (r *Archive) seal(ctx context.Context, batch archive.Batch) (archive.Batch, error) {
	if !strings.IsEmpty(batch.ContentDigest) {
		return batch, nil
	}

	sealBatch := r.statements.MustLookup("queries/archive/seal_batch.sql")

	digest, err := r.sourceDigest(ctx, batch.ID)
	if err != nil {
		return batch, err
	}
	batch.ContentDigest = digest

	_, err = r.db.ExecContext(ctx, sealBatch, digest, batch.ID)
	return batch, err
}

// VisitCompleted streams completed batches from durable state. A visitor error
// ends the walk. The visitor may requeue a batch whose local file needs repair.
func (r *Archive) VisitCompleted(ctx context.Context, visit func(archive.StagedBatch) error) error {
	statement := r.statements.MustLookup("queries/archive/completed_batches.sql")

	rows, err := r.db.QueryContext(ctx, statement)
	if err != nil {
		return err
	}
	defer rows.Close()

	for rows.Next() {
		var b archive.StagedBatch
		if err := rows.Scan(&b.ID, &b.Day, &b.ContentDigest, &b.Checksum); err != nil {
			return err
		}

		if err := visit(b); err != nil {
			return err
		}
	}
	return rows.Err()
}

// Complete records the checksum of a verified, closed Parquet file.
func (r *Archive) Complete(ctx context.Context, id, checksum string) error {
	statement := r.statements.MustLookup("queries/archive/complete_batch.sql")

	_, err := r.db.ExecContext(ctx, statement, checksum, id)
	return err
}

// Requeue clears the file checksum while keeping the batch and its exact membership.
func (r *Archive) Requeue(ctx context.Context, id string) error {
	statement := r.statements.MustLookup("queries/archive/requeue_batch.sql")

	_, err := r.db.ExecContext(ctx, statement, id)
	return err
}

func (r *Archive) create(ctx context.Context, eventBefore, receiptBefore time.Time, order sql.Null[int64]) (archive.Batch, error) {
	nextDay := r.statements.MustLookup("queries/archive/next_day.sql")
	assignMembers := r.statements.MustLookup("queries/archive/assign_members.sql")
	insertBatch := r.statements.MustLookup("queries/archive/insert_batch.sql")

	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return archive.Batch{}, err
	}
	defer tx.Rollback()

	eventLimit, receiptLimit := unixNanoseconds(eventBefore).String(), unixNanoseconds(receiptBefore).String()
	var b archive.Batch
	err = tx.QueryRowContext(ctx, nextDay, eventLimit, receiptLimit, order).Scan(&b.ID, &b.Day)
	if errors.Is(err, sql.ErrNoRows) {
		return archive.Batch{}, nil
	}
	if err != nil {
		return archive.Batch{}, err
	}

	if _, err := tx.ExecContext(ctx, assignMembers, b.ID, b.Day, receiptLimit); err != nil {
		return archive.Batch{}, err
	}

	if _, err := tx.ExecContext(ctx, insertBatch, b.ID, b.Day); err != nil {
		return archive.Batch{}, err
	}

	if err := tx.Commit(); err != nil {
		return archive.Batch{}, err
	}

	return b, nil
}
