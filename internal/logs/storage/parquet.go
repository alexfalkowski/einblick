package storage

import (
	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/errors"
)

// WriteParquet writes the immutable batch to path through DuckDB. It reads the
// result back to verify the logical contents before returning success.
func (r *Archive) WriteParquet(ctx context.Context, batch archive.Batch, path string) error {
	if _, err := r.db.ExecContext(ctx, copyBatchQuery, batch.ID, path); err != nil {
		return err
	}

	rows, err := r.db.QueryContext(ctx, parquetRowsQuery, path)
	if err != nil {
		return err
	}

	digest, err := archiveContentDigest(rows)
	if err != nil {
		return err
	}
	if digest != batch.ContentDigest {
		return errors.New("log archive Parquet contents differ from batch")
	}

	return nil
}
