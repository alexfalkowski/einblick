package storage

import (
	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/database/sql"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
	"github.com/duckdb/duckdb-go/v2"
)

// objectTimes maps archive keys to their object storage timestamps.
type objectTimes = map[string]time.Time

type archiveList struct {
	objects objectTimes
	// expired holds objects whose age and disappearance were confirmed during the refresh.
	expired map[string]struct{}
}

func logPageSQL(archived string) string {
	return strings.Concat("WITH selected_logs AS (", localLogsQuery, archived, ") ", listLogsQuery)
}

func (r *repository) readHistory(ctx context.Context, query Query, position cursor) (*Page, error) {
	retention := r.store.Retention()
	var expirationCutoff time.Time
	if retention > 0 {
		expirationCutoff = time.Now().Add(-retention.Duration())
	}

	keys, err := archive.Discover(ctx, r.store, query.StartTime, query.EndTime)
	if err != nil {
		return nil, errors.Prefix("discover log archive", err)
	}

	page, err := r.readArchivePage(ctx, query, position, archiveList{objects: keys}, expirationCutoff)
	if err == nil || ctx.Err() != nil || retention == 0 {
		return page, err
	}

	expirationCutoff = time.Now().Add(-retention.Duration())

	current, err := r.relistArchive(ctx, query, keys, expirationCutoff, err)
	if err != nil {
		return nil, err
	}

	return r.readArchivePage(ctx, query, position, current, expirationCutoff)
}

func (r *repository) relistArchive(ctx context.Context, query Query, keys objectTimes, cutoff time.Time, cause error) (archiveList, error) {
	missing := r.missingExpiredObject(cause, keys, cutoff)
	if strings.IsEmpty(missing) {
		return archiveList{}, cause
	}

	// Confirm the expired object disappeared before retrying with a new snapshot.
	current, err := archive.Discover(ctx, r.store, query.StartTime, query.EndTime)
	if err != nil {
		return archiveList{}, errors.Prefix("refresh log archive", err)
	}
	if _, listed := current[missing]; listed {
		return archiveList{}, cause
	}

	expired := make(map[string]struct{})
	for key, storedAt := range keys {
		if _, listed := current[key]; listed {
			continue
		}
		if !expiredObject(storedAt, cutoff) {
			return archiveList{}, cause
		}
		expired[key] = struct{}{}
	}

	return archiveList{objects: current, expired: expired}, nil
}

func (r *repository) missingExpiredObject(err error, keys objectTimes, cutoff time.Time) string {
	failure, ok := errors.AsType[*duckdb.Error](err)
	if !ok || failure.Type != duckdb.ErrorTypeHTTP || !strings.Contains(failure.Msg, "HTTP 404") {
		return strings.Empty
	}

	for key, storedAt := range keys {
		if expiredObject(storedAt, cutoff) && strings.Contains(failure.Msg, strings.Concat("'", r.store.URI(key), "'")) {
			return key
		}
	}
	return strings.Empty
}

func expiredObject(storedAt, cutoff time.Time) bool {
	return !cutoff.IsZero() && !storedAt.IsZero() && !storedAt.After(cutoff)
}

func (r *repository) readArchivePage(ctx context.Context, query Query, position cursor, list archiveList, cutoff time.Time) (*Page, error) {
	// The snapshot supplies local rows and reconciles batches evicted since listing.
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	evicted, err := archiveSources(ctx, tx, query, list, cutoff)
	if err != nil {
		return nil, err
	}

	args := pageArgs(query, position)
	var archived string
	if len(list.objects) > 0 {
		locations := make([]string, 0, len(list.objects))
		for key := range list.objects {
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

	return scanPage(ctx, rows, query.PageSize, &position)
}

func archiveSources(ctx context.Context, tx *sql.Tx, query Query, listing archiveList, expirationCutoff time.Time) ([]string, error) {
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
		var storedAt sql.NullTime
		if err := rows.Scan(&batch.ID, &batch.Day, &isEvicted, &storedAt); err != nil {
			return nil, err
		}

		key := batch.Key()
		if !isEvicted {
			delete(listing.objects, key)
			continue
		}
		if _, expired := listing.expired[key]; expired {
			continue
		}

		// Asynchronous lifecycle deletion can leave eligible objects readable.
		// Keep all listed objects, and require unlisted objects during retention.
		listedAt, listed := listing.objects[key]

		objectTime := archive.StoredAtForExpiration(listedAt, storedAt.Time)

		if !listed && expiredObject(objectTime, expirationCutoff) {
			continue
		}
		listing.objects[key] = objectTime
		evicted = append(evicted, key)
	}
	return evicted, rows.Err()
}
