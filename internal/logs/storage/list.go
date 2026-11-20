package storage

import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"math/big"
	"strconv"

	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/encoding/json"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/strings"
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
	BeforeNS  string `json:"before_ns"`
	QueryHash string `json:"query_hash"`
	BeforeID  int64  `json:"before_id"`
}

// List executes a fixed, bounded query. It propagates cancellation through queue
// waits and SQL execution. No partial page is returned.
func (r *repository) List(ctx context.Context, query Query) (*Page, error) {
	ctx, cancel := context.WithTimeout(ctx, r.config.Timeout)
	defer cancel()

	query.StartTime, query.EndTime = query.StartTime.UTC(), query.EndTime.UTC()
	if query.PageSize == 0 {
		query.PageSize = r.config.MaxResults
	}

	if err := r.validateQuery(query); err != nil {
		return nil, err
	}

	if err := r.queries.Acquire(ctx, 1); err != nil {
		return nil, err
	}
	defer r.queries.Release(1)

	position, err := queryCursor(query)
	if err != nil {
		return nil, err
	}
	return r.readPage(ctx, query, position)
}

func (r *repository) readPage(ctx context.Context, query Query, position *cursor) (*Page, error) {
	trace, _ := hex.DecodeString(query.TraceID)
	severity := strings.Empty
	if !strings.IsEmpty(query.Severity) {
		severity = strings.Concat("SEVERITY_NUMBER_", query.Severity)
	}

	rows, err := r.db.QueryContext(ctx, listLogsQuery,
		unixNanoseconds(query.StartTime).String(), unixNanoseconds(query.EndTime).String(),
		position.BeforeNS, position.BeforeNS, position.BeforeID,
		query.Service, query.Service, severity, severity, query.Text, query.Text,
		query.TraceID, base64.StdEncoding.EncodeToString(trace), query.PageSize+1)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	page := &Page{Logs: make([]*Log, 0, query.PageSize)}
	for rows.Next() {
		var log Log
		var event, received uint64
		var resource, scope, record string
		if err := rows.Scan(&log.ID, &event, &received, &resource, &scope, &record); err != nil {
			return nil, err
		}
		log.EventTime, log.ReceiveTime = timestamp(event), timestamp(received)
		log.Resource, log.Scope, log.Record = json.RawMessage(resource), json.RawMessage(scope), json.RawMessage(record)
		page.Logs = append(page.Logs, &log)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	if len(page.Logs) <= query.PageSize {
		return page, nil
	}

	page.Logs = page.Logs[:query.PageSize]
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
