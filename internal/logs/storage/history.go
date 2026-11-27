package storage

import (
	"strconv"

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

type sqlQuery func(ctx context.Context, statement string, args ...any) (*sql.Rows, error)

// queryLogSources executes and scans a query before its archive snapshot closes.
type queryLogSources func(queryRows sqlQuery, evictedLocations, archiveLocations []string) error

func (r *repository) readHistory(ctx context.Context, query Query, runQuery queryLogSources) error {
	retention := r.store.Retention()
	var expirationCutoff time.Time
	if retention > 0 {
		expirationCutoff = time.Now().Add(-retention.Duration())
	}

	keys, err := archive.Discover(ctx, r.store, query.StartTime, query.EndTime)
	if err != nil {
		return errors.Prefix("discover log archive", err)
	}

	err = r.readArchiveLogs(ctx, query, archiveList{objects: keys}, expirationCutoff, runQuery)
	if err == nil || ctx.Err() != nil || retention == 0 {
		return err
	}

	expirationCutoff = time.Now().Add(-retention.Duration())

	current, err := r.relistArchive(ctx, query, keys, expirationCutoff, err)
	if err != nil {
		return err
	}

	return r.readArchiveLogs(ctx, query, current, expirationCutoff, runQuery)
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

func (r *repository) readArchiveLogs(ctx context.Context, query Query, list archiveList, cutoff time.Time, runQuery queryLogSources) error {
	// The snapshot supplies local rows and reconciles batches evicted since listing.
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	evicted, err := archiveSources(ctx, tx, query, list, cutoff)
	if err != nil {
		return err
	}

	if len(list.objects) == 0 {
		return runQuery(tx.QueryContext, nil, nil)
	}
	locations := make([]string, 0, len(list.objects))
	for key := range list.objects {
		locations = append(locations, r.store.URI(key))
	}
	for i, key := range evicted {
		evicted[i] = r.store.URI(key)
	}
	return runQuery(tx.QueryContext, evicted, locations)
}

func archiveDays(query Query) (string, string) {
	return query.StartTime.Format(archive.DayLayout), query.EndTime.Add(-time.Nanosecond.Duration()).Format(archive.DayLayout)
}

func archiveSources(ctx context.Context, tx *sql.Tx, query Query, listing archiveList, expirationCutoff time.Time) ([]string, error) {
	startDay, endDay := archiveDays(query)
	rows, err := tx.QueryContext(ctx, archiveSourcesQuery, startDay, endDay)
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

func archivePageEnd(query Query, position cursor) time.Time {
	if position.BeforeID > 0 {
		beforeNS, _ := strconv.ParseUint(position.BeforeNS, 10, 64)
		end := timestamp(beforeNS).Add(time.Nanosecond.Duration())
		if end.After(query.StartTime) && end.Before(query.EndTime) {
			return end
		}
	}
	return query.EndTime
}
