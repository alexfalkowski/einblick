package storage

import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"math"
	"math/big"
	"strconv"

	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/database/sql"
	"github.com/alexfalkowski/go-service/v3/encoding/json"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
	"github.com/alexfalkowski/go-sync"
	logs "go.opentelemetry.io/proto/otlp/logs/v1"
)

// ErrInvalidQuery identifies invalid filters, bounds or pagination tokens.
var ErrInvalidQuery = errors.New("logs: invalid query")

// ErrTimeBounds identifies search dates outside the supported OTLP timestamp range.
var ErrTimeBounds = errors.New("logs: dates outside the supported range")

// ErrTimeOrder identifies a search end time at or before its start time.
var ErrTimeOrder = errors.New("logs: end time must be after start time")

// ErrTimeRangeTooWide identifies a search interval longer than the configured maximum.
var ErrTimeRangeTooWide = errors.New("logs: search interval exceeds the configured maximum")

const timestampBits = 64

type cursor struct {
	BeforeNS     string `json:"before_ns"`
	QueryHash    string `json:"query_hash"`
	BeforeSource string `json:"before_source,omitempty"`
	BeforeID     int64  `json:"before_id"`
}

var maxPageTokenLength = cursorTokenLimit()

// logSearch runs a validated query while its source's admission slot is held.
type logSearch func(ctx context.Context, query Query) error

type searchKind uint8

const (
	pageSearch searchKind = iota
	activitySearch
)

// List executes a fixed, bounded query. It propagates cancellation through queue
// waits and SQL execution. No partial page is returned.
func (r *repository) List(ctx context.Context, query Query) (*Page, error) {
	var page *Page
	err := r.search(ctx, query, pageSearch, func(ctx context.Context, query Query) error {
		position, err := queryCursor(query)
		if err != nil {
			return err
		}

		if includesHistoricalRange(ctx, query.StartTime) {
			query.EndTime = archivePageEnd(query, *position)
		}

		args := append(filterArgs(query),
			position.BeforeNS, position.BeforeNS, position.BeforeID, position.BeforeID, position.BeforeSource, query.PageSize+1,
		)

		return r.queryLogs(ctx, query, listLogsQuery, args, func(rows *sql.Rows) error {
			page, err = scanPage(ctx, rows, query.PageSize, position)
			return err
		})
	})
	if err != nil {
		return nil, err
	}
	return page, nil
}

func (r *repository) search(ctx context.Context, query Query, kind searchKind, run logSearch) error {
	ctx, cancel := context.WithTimeout(ctx, r.config.Timeout)
	defer cancel()

	query.StartTime, query.EndTime = query.StartTime.UTC(), query.EndTime.UTC()
	if query.PageSize == 0 {
		query.PageSize = r.config.MaxResults
	}

	if err := r.validateQuery(query); err != nil {
		return err
	}

	admission, err := r.acquireSearch(ctx, query.StartTime, kind)
	if err != nil {
		return err
	}
	defer admission.Release(1)

	err = run(ctx, query)
	if ctxErr := ctx.Err(); ctxErr != nil {
		return ctxErr
	}
	return err
}

func (r *repository) acquireSearch(ctx context.Context, start time.Time, kind searchKind) (*sync.Semaphore, error) {
	if r.store == nil || !includesHistoricalRange(ctx, start) {
		return r.localQueries, r.localQueries.Acquire(ctx, 1)
	}
	if kind == pageSearch {
		return r.archiveQueries, r.archiveQueries.Acquire(ctx, 1)
	}
	if err := ctx.Err(); err != nil {
		return nil, err
	}

	// Check spare capacity atomically, then return the page slot before activity starts.
	const activitySlot, pageSlot = 1, 1
	if !r.archiveQueries.TryAcquire(activitySlot + pageSlot) {
		return nil, errors.New("logs: no spare archive slot for activity")
	}
	defer r.archiveQueries.Release(pageSlot)

	return r.archiveQueries, nil
}

func includesHistoricalRange(ctx context.Context, startTime time.Time) bool {
	// Use the deadline so ranges read locally stay local across midnight UTC.
	deadline, _ := ctx.Deadline()
	return startTime.Before(archive.LocalWindowStart(deadline))
}

func (r *repository) queryLogs(ctx context.Context, query Query, statement string, args []any, scan func(*sql.Rows) error) error {
	runQuery := func(queryRows sqlQuery, evictedLocations, archiveLocations []string) error {
		archived := strings.Empty
		queryArgs := args
		if len(archiveLocations) > 0 {
			archived = archivedLogsQuery
			queryArgs = append([]any{evictedLocations, archiveLocations}, args...)
		}

		querySQL := strings.Concat(
			"WITH selected_logs AS (", localLogsQuery, archived, "), filtered_logs AS (", filterLogsQuery, ") ", statement,
		)
		rows, err := queryRows(ctx, querySQL, queryArgs...)
		if err != nil {
			return err
		}
		defer rows.Close()

		return scan(rows)
	}

	if includesHistoricalRange(ctx, query.StartTime) {
		if r.store != nil {
			return r.readHistory(ctx, query, runQuery)
		}
		if err := r.checkLocalHistory(ctx, query); err != nil {
			return err
		}
	}

	return runQuery(r.db.QueryContext, nil, nil)
}

func (r *repository) checkLocalHistory(ctx context.Context, query Query) error {
	startDay, endDay := archiveDays(query)

	var evicted bool
	if err := r.db.QueryRowContext(ctx, archiveEvictionsQuery, startDay, endDay).Scan(&evicted); err != nil {
		return err
	}
	if evicted {
		return errors.New("log archive is unavailable for the requested range")
	}
	return nil
}

func filterArgs(query Query) []any {
	trace, _ := hex.DecodeString(query.TraceID)

	var severity string
	if !strings.IsEmpty(query.Severity) {
		severity = strings.Concat("SEVERITY_NUMBER_", query.Severity)
	} else {
		severity = strings.Empty
	}

	return []any{
		unixNanoseconds(query.StartTime).String(), unixNanoseconds(query.EndTime.Add(-time.Nanosecond.Duration())).String(),
		query.Service, query.Service, severity, severity, query.Text, query.Text,
		query.TraceID, base64.StdEncoding.EncodeToString(trace),
	}
}

func scanPage(ctx context.Context, rows *sql.Rows, size int, position *cursor) (*Page, error) {
	page := &Page{Logs: make([]*Log, 0, size)}
	for rows.Next() {
		var log Log
		var event, received uint64
		var resource, scope, record, source string
		if err := rows.Scan(&log.ID, &event, &received, &resource, &scope, &record, &source); err != nil {
			return nil, err
		}

		log.EventTime, log.ReceiveTime = timestamp(event), timestamp(received)
		log.Resource, log.Scope, log.Record = json.RawMessage(resource), json.RawMessage(scope), json.RawMessage(record)

		page.Logs = append(page.Logs, &log)
		if len(page.Logs) == size {
			position.BeforeSource = source
		}
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	if len(page.Logs) <= size {
		return page, nil
	}

	page.Logs = page.Logs[:size]
	last := page.Logs[len(page.Logs)-1]
	position.BeforeNS, position.BeforeID = unixNanoseconds(last.EventTime).String(), last.ID

	content, err := json.Marshal(position)
	if err != nil {
		return nil, err
	}

	page.NextPageToken = base64.RawURLEncoding.EncodeToString(content)
	return page, nil
}

func (r *repository) validateQuery(query Query) error {
	if err := r.validateRange(query); err != nil {
		return err
	}

	if query.PageSize < 1 || query.PageSize > r.config.MaxResults {
		return ErrInvalidQuery
	}

	if !strings.IsEmpty(query.Severity) {
		if _, ok := logs.SeverityNumber_value[strings.Concat("SEVERITY_NUMBER_", query.Severity)]; !ok {
			return ErrInvalidQuery
		}
	}

	if !strings.IsEmpty(query.TraceID) && !ValidTraceID(query.TraceID) {
		return ErrInvalidQuery
	}

	return nil
}

func (r *repository) validateRange(query Query) error {
	start, end := unixNanoseconds(query.StartTime), unixNanoseconds(query.EndTime)
	if start.Sign() < 0 || start.BitLen() > timestampBits || end.Cmp(new(big.Int).Lsh(big.NewInt(1), timestampBits)) > 0 {
		return errors.Join(ErrInvalidQuery, ErrTimeBounds)
	}

	if end.Cmp(start) <= 0 {
		return errors.Join(ErrInvalidQuery, ErrTimeOrder)
	}

	if new(big.Int).Sub(end, start).Cmp(big.NewInt(int64(r.config.MaxRange))) > 0 {
		return errors.Join(ErrInvalidQuery, ErrTimeRangeTooWide)
	}

	return nil
}

func queryCursor(query Query) (*cursor, error) {
	token := query.PageToken
	if len(token) > maxPageTokenLength {
		return nil, ErrInvalidQuery
	}

	query.PageToken = strings.Empty
	content, err := json.Marshal(query)
	if err != nil {
		return nil, err
	}

	// Bind normalized filters without repeating large text in every token.
	sum := sha256.Sum256(content)
	fingerprint := hex.EncodeToString(sum[:])

	if !strings.IsEmpty(token) {
		content, err := base64.RawURLEncoding.DecodeString(token)
		if err != nil {
			return nil, ErrInvalidQuery
		}

		var position cursor
		if err := json.Unmarshal(content, &position); err != nil {
			return nil, ErrInvalidQuery
		}

		_, err = strconv.ParseUint(position.BeforeNS, 10, 64)
		if err != nil || position.QueryHash != fingerprint || position.BeforeID <= 0 {
			return nil, ErrInvalidQuery
		}

		return &position, nil
	}

	return &cursor{QueryHash: fingerprint, BeforeNS: unixNanoseconds(query.EndTime).String()}, nil
}

func cursorTokenLimit() int {
	// Bound the token by the largest values that can appear in an emitted cursor.
	longest := cursor{
		BeforeNS:     strconv.FormatUint(math.MaxUint64, 10),
		QueryHash:    hex.EncodeToString(make([]byte, sha256.Size)),
		BeforeSource: "00000000-0000-0000-0000-000000000000",
		BeforeID:     math.MaxInt64,
	}
	content, _ := json.Marshal(longest) // The cursor only contains strings and an integer.
	return base64.RawURLEncoding.EncodedLen(len(content))
}
