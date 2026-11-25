package storage

import (
	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/database/sql"
)

// Backlog reads the unpublished record totals and publication state in one snapshot.
func (r *Archive) Backlog(ctx context.Context) (archive.Backlog, error) {
	var backlog archive.Backlog
	var oldest sql.Null[uint64]
	row := r.db.QueryRowContext(ctx, archiveBacklogQuery)
	if err := row.Scan(&backlog.PendingRecords, &backlog.PendingRecordBytes, &oldest, &backlog.LastPublishedAt); err != nil {
		return archive.Backlog{}, err
	}
	if oldest.Valid {
		backlog.OldestReceivedAt = timestamp(oldest.V)
	}
	return backlog, nil
}
