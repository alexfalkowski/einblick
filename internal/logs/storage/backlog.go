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
	var last sql.NullTime
	row := r.db.QueryRowContext(ctx, archiveBacklogQuery)
	if err := row.Scan(&backlog.PendingRecords, &backlog.PendingRecordBytes, &oldest, &last); err != nil {
		return archive.Backlog{}, err
	}
	if oldest.Valid {
		backlog.OldestReceivedAt = timestamp(oldest.V)
	}
	if last.Valid {
		backlog.LastPublishedAt = &last.Time
	}
	return backlog, nil
}
