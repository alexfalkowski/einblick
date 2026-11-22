package storage

import (
	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/database/sql"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
)

func logPageSQL(archived string) string {
	return strings.Concat("WITH selected_logs AS (", localLogsQuery, archived, ") ", listLogsQuery)
}

func (r *repository) readHistory(ctx context.Context, query Query, position *cursor, args []any) (*Page, error) {
	keys, err := archive.Discover(ctx, r.store, query.StartTime, query.EndTime)
	if err != nil {
		return nil, errors.Prefix("discover log archive", err)
	}

	// The snapshot classifies listed keys and supplies the local rows. A batch
	// can be evicted after listing, so also include all expected evicted keys.
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	evicted, err := archiveSources(ctx, tx, query, keys)
	if err != nil {
		return nil, err
	}

	var archived string
	if len(keys) > 0 {
		locations := make([]string, 0, len(keys))
		for key := range keys {
			locations = append(locations, r.store.URI(key))
		}

		for i, key := range evicted {
			evicted[i] = r.store.URI(key)
		}

		archived = archivedLogsQuery
		args = append([]any{evicted, locations}, args...)
	}

	rows, err := tx.QueryContext(ctx, logPageSQL(archived), args...)
	if err != nil {
		return nil, err
	}
	return scanPage(ctx, rows, query.PageSize, position)
}

func archiveSources(ctx context.Context, tx *sql.Tx, query Query, keys map[string]struct{}) ([]string, error) {
	rows, err := tx.QueryContext(ctx, archiveSourcesQuery, query.StartTime.Format(archive.DayLayout),
		query.EndTime.Add(-time.Nanosecond.Duration()).Format(archive.DayLayout))
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	evicted := []string{}
	for rows.Next() {
		var batch archive.Batch
		var isEvicted bool
		if err := rows.Scan(&batch.ID, &batch.Day, &isEvicted); err != nil {
			return nil, err
		}

		key := batch.Key()
		if isEvicted {
			keys[key] = struct{}{}
			evicted = append(evicted, key)
		} else {
			delete(keys, key)
		}
	}
	return evicted, rows.Err()
}
