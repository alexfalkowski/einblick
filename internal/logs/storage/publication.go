package storage

import (
	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/database/sql"
	"github.com/alexfalkowski/go-service/v3/errors"
)

// NextPublication records an attempt on the longest-waiting eligible batch.
func (r *Archive) NextPublication(ctx context.Context) (archive.Publication, error) {
	return r.nextPublication(ctx, true)
}

// NextReconciliation records an attempt on the longest-waiting batch with
// pending cleanup or a recorded upload attempt.
func (r *Archive) NextReconciliation(ctx context.Context) (archive.Publication, error) {
	return r.nextPublication(ctx, false)
}

func (r *Archive) nextPublication(ctx context.Context, allowUpload bool) (archive.Publication, error) {
	statement := r.statements.MustLookup("queries/archive/next_publication.sql")

	var b archive.Publication
	row := r.db.QueryRowContext(ctx, statement, allowUpload)
	err := row.Scan(&b.ID, &b.Day, &b.ContentDigest, &b.Checksum, &b.PublishedChecksum)
	if errors.Is(err, sql.ErrNoRows) {
		return archive.Publication{}, nil
	}
	return b, err
}

// RecordUpload keeps the byte identity across retries and restaging.
func (r *Archive) RecordUpload(ctx context.Context, id, checksum string) error {
	statement := r.statements.MustLookup("queries/archive/record_upload.sql")
	_, err := r.db.ExecContext(ctx, statement, id, checksum)
	return err
}

// HasUpload checks whether this batch could have written the remote bytes.
func (r *Archive) HasUpload(ctx context.Context, id, checksum string) (bool, error) {
	statement := r.statements.MustLookup("queries/archive/has_upload.sql")

	var exists bool
	err := r.db.QueryRowContext(ctx, statement, id, checksum).Scan(&exists)
	return exists, err
}

// ConfirmPublication commits the remote checksum and drops unneeded attempts.
func (r *Archive) ConfirmPublication(ctx context.Context, id, checksum string) error {
	confirmPublication := r.statements.MustLookup("queries/archive/confirm_publication.sql")
	clearUploads := r.statements.MustLookup("queries/archive/clear_uploads.sql")

	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	if _, err := tx.ExecContext(ctx, confirmPublication, checksum, id); err != nil {
		return err
	}

	if _, err := tx.ExecContext(ctx, clearUploads, id); err != nil {
		return err
	}

	return tx.Commit()
}

// FinishCleanup clears durable cleanup work after the confirmed file is gone.
func (r *Archive) FinishCleanup(ctx context.Context, id string) error {
	statement := r.statements.MustLookup("queries/archive/finish_cleanup.sql")
	_, err := r.db.ExecContext(ctx, statement, id)
	return err
}
