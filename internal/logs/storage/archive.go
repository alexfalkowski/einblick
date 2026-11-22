package storage

import (
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"

	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/database/sql"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/strings"
)

// Five 64-bit fields give each projected candidate at least 40 source bytes.
const minimumRowBytes = 5 * 8

// NewArchive provides durable batch state and Parquet writes over one DuckDB connection.
func NewArchive(db *sql.DB) *Archive {
	return &Archive{db: db}
}

// Archive owns durable log batch state and native Parquet operations.
type Archive struct {
	db *sql.DB
}

// Next returns the oldest pending batch or claims a new batch up to the target
// size. A single larger accepted row may form its own batch. The zero batch
// indicates an empty queue. The archive worker calls Next serially.
func (r *Archive) Next(ctx context.Context, batchBytes int64) (archive.Batch, error) {
	var b archive.Batch
	err := r.db.QueryRowContext(ctx, nextBatchQuery).Scan(&b.ID, &b.Day, &b.ContentDigest)
	if errors.Is(err, sql.ErrNoRows) {
		return r.create(ctx, batchBytes)
	}
	return b, err
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

func (r *Archive) create(ctx context.Context, batchBytes int64) (archive.Batch, error) {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return archive.Batch{}, err
	}
	defer tx.Rollback()

	var b archive.Batch
	err = tx.QueryRowContext(ctx, nextDayQuery).Scan(&b.ID, &b.Day)
	if errors.Is(err, sql.ErrNoRows) {
		return archive.Batch{}, nil
	}
	if err != nil {
		return archive.Batch{}, err
	}

	// Include one candidate even when the configured target is smaller.
	limit := max(batchBytes/minimumRowBytes, 1)
	if _, err := tx.ExecContext(ctx, assignMembersQuery, minimumRowBytes, b.Day, limit, b.ID, batchBytes); err != nil {
		return archive.Batch{}, err
	}

	rows, err := tx.QueryContext(ctx, sourceRowsQuery, b.ID)
	if err != nil {
		return archive.Batch{}, err
	}

	b.ContentDigest, err = archiveContentDigest(rows)
	if err != nil {
		return archive.Batch{}, err
	}

	if _, err := tx.ExecContext(ctx, insertBatchQuery, b.ID, b.Day, b.ContentDigest); err != nil {
		return archive.Batch{}, err
	}

	if err := tx.Commit(); err != nil {
		return archive.Batch{}, err
	}

	return b, nil
}

// archiveContentDigest identifies v1 logical rows independently of Parquet encoding.
// It consumes and closes rows from the v1 projection in log-ID order. Length
// prefixes keep delimiters in stored protobuf JSON from changing field boundaries.
func archiveContentDigest(rows *sql.Rows) (string, error) {
	defer rows.Close()

	hash := sha256.New()
	_, _ = hash.Write([]byte("einblick/logs/v1\x00"))

	var length [8]byte
	for rows.Next() {
		var id, timestamp, observed, received, event, resource, scope, record string
		if err := rows.Scan(&id, &timestamp, &observed, &received, &event, &resource, &scope, &record); err != nil {
			return strings.Empty, err
		}

		for _, value := range [...]string{id, timestamp, observed, received, event, resource, scope, record} {
			binary.BigEndian.PutUint64(length[:], uint64(len(value)))
			_, _ = hash.Write(length[:])
			_, _ = hash.Write([]byte(value))
		}
	}

	return hex.EncodeToString(hash.Sum(nil)), rows.Err()
}
