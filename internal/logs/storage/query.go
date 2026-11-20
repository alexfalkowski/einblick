package storage

import (
	"github.com/alexfalkowski/go-service/v3/encoding/json"
	"github.com/alexfalkowski/go-service/v3/time"
)

// Query selects one recent-log page. Filters are conjunctive and remain fixed
// across pages; SQL text and arbitrary expressions are never accepted.
type Query struct {
	// StartTime is the inclusive absolute time, encoded as RFC 3339 with nanosecond precision.
	StartTime time.Time `json:"start_time"`

	// EndTime is the exclusive absolute time. Query bounds must fit the stored OTLP time range.
	EndTime time.Time `json:"end_time"`

	// Service exactly matches the string resource attribute service.name; empty selects all.
	Service string `json:"service"`

	// Severity is an exact OTLP severity suffix, such as INFO or ERROR; empty selects all.
	Severity string `json:"severity"`

	// Text is a case-sensitive literal substring of string bodies only; empty selects all.
	Text string `json:"text"`

	// TraceID is a 32-character hexadecimal trace ID; empty selects all.
	TraceID string `json:"trace_id"`

	// PageToken continues a previous query with identical filters and page size.
	PageToken string `json:"page_token"`

	// PageSize requests at most Config.MaxResults records; zero uses that maximum.
	PageSize int `json:"page_size"`
}

// Page contains complete records in descending event-time/ID order. Errors
// return no page; an empty Logs slice means no matches in the local database.
type Page struct {
	// NextPageToken is empty at exhaustion. It is opaque, query-bound and stateless.
	NextPageToken string `json:"next_page_token"`

	// Logs contains records with their original typed protobuf JSON context.
	Logs []*Log `json:"logs"`
}

// Log retains a stored record and its shared headers without flattening typed values.
type Log struct {
	// EventTime is the selected Timestamp/ObservedTimestamp/receipt time, encoded as RFC 3339.
	EventTime time.Time `json:"event_time"`

	// ReceiveTime is server receipt time in RFC 3339, separate from original record times.
	ReceiveTime time.Time `json:"receive_time"`

	// Resource is the complete protobuf JSON ResourceLogs header without scopes.
	Resource json.RawMessage `json:"resource"`

	// Scope is the complete protobuf JSON ScopeLogs header without records.
	Scope json.RawMessage `json:"scope"`

	// Record is the original complete protobuf JSON LogRecord.
	Record json.RawMessage `json:"record"`

	// ID is the local identity, encoded as decimal to preserve integer precision.
	ID int64 `json:"id,string"`
}
