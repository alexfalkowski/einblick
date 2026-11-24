package storage

import (
	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/database/sql"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
)

// NewArchive provides durable batch state and Parquet exports backed by DuckDB.
func NewArchive(db *sql.DB) *Archive {
	return &Archive{db: db}
}

// Archive owns durable log batch state and Parquet content verification.
type Archive struct {
	db *sql.DB
}

// Next selects the earliest work and advances the attempted batch to the end
// of the staging queue. The worker calls Next serially.
func (r *Archive) Next(ctx context.Context, eventBefore, receiptBefore time.Time) (archive.Batch, error) {
	var pending archive.Batch
	var order sql.Null[int64]
	err := r.db.QueryRowContext(ctx, nextBatchQuery).Scan(&pending.ID, &pending.Day, &pending.ContentDigest, &order)
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

	if _, err := r.db.ExecContext(ctx, rotateStagingQuery, pending.ID); err != nil {
		return pending, err
	}
	return r.seal(ctx, pending)
}

func (r *Archive) seal(ctx context.Context, batch archive.Batch) (archive.Batch, error) {
	if !strings.IsEmpty(batch.ContentDigest) {
		return batch, nil
	}

	digest, err := r.sourceDigest(ctx, batch.ID)
	if err != nil {
		return batch, err
	}
	batch.ContentDigest = digest
	_, err = r.db.ExecContext(ctx, sealBatchQuery, digest, batch.ID)
	return batch, err
}

// VisitCompleted streams completed batches from durable state. A visitor error
// ends the walk. The visitor may requeue a batch whose local file needs repair.
func (r *Archive) VisitCompleted(ctx context.Context, visit func(archive.StagedBatch) error) error {
	rows, err := r.db.QueryContext(ctx, completedBatchesQuery)
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
	_, err := r.db.ExecContext(ctx, completeBatchQuery, checksum, id)
	return err
}

// Requeue clears the file checksum while keeping the batch and its exact membership.
func (r *Archive) Requeue(ctx context.Context, id string) error {
	_, err := r.db.ExecContext(ctx, requeueBatchQuery, id)
	return err
}

func (r *Archive) create(ctx context.Context, eventBefore, receiptBefore time.Time, order sql.Null[int64]) (archive.Batch, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return archive.Batch{}, err
	}
	defer tx.Rollback()

	eventLimit, receiptLimit := unixNanoseconds(eventBefore).String(), unixNanoseconds(receiptBefore).String()
	var b archive.Batch
	err = tx.QueryRowContext(ctx, nextDayQuery, eventLimit, receiptLimit, order).Scan(&b.ID, &b.Day)
	if errors.Is(err, sql.ErrNoRows) {
		return archive.Batch{}, nil
	}
	if err != nil {
		return archive.Batch{}, err
	}

	if _, err := tx.ExecContext(ctx, assignMembersQuery, b.ID, b.Day, receiptLimit); err != nil {
		return archive.Batch{}, err
	}

	if _, err := tx.ExecContext(ctx, insertBatchQuery, b.ID, b.Day); err != nil {
		return archive.Batch{}, err
	}

	if err := tx.Commit(); err != nil {
		return archive.Batch{}, err
	}

	return b, nil
}
