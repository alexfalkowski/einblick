package model

import (
	"github.com/alexfalkowski/einblick/internal/site/timerange"
	"github.com/alexfalkowski/go-service/v3/time"
)

// Logs contains the filters and results for the full and partial views.
type Logs struct {
	// NextURL continues the current search. It is empty on the last page.
	NextURL string

	// QueryURL opens the first page with the current filters and time selection.
	QueryURL string

	// ActivityURL counts matching logs over the applied filters and exact interval.
	ActivityURL string

	// Rows contains matching logs in newest-first order.
	Rows []LogRow

	// Filters contains the active selections as displayed in the form.
	Filters Filters
}

// Filters holds the display values for the log search form.
type Filters struct {
	// Earliest is the first date selectable under the archive lookback, when configured.
	Earliest time.Time

	// StartTime is the inclusive UTC bound submitted with filters and pagination.
	StartTime time.Time

	// EndTime is the exclusive UTC bound submitted with filters and pagination.
	EndTime time.Time

	// ServiceName is the exact selected service. Empty selects all services.
	ServiceName string

	// MessageText is the literal text to find within string log messages.
	MessageText string

	// Severity is the selected level. Empty selects all levels.
	Severity string

	// TraceID is the hexadecimal identifier selected for correlation.
	TraceID string

	// SelectedWindow is the selected relative preset shown in the time picker.
	SelectedWindow string

	// RecentWindow is the preset for the next search. An empty value keeps the absolute bounds.
	RecentWindow string

	// SeverityOptions lists the available levels in ascending severity order.
	SeverityOptions []FilterOption

	// Windows holds the recent ranges that fit the configured search limit.
	Windows []timerange.Preset

	// PageSize is the requested number of results. Zero uses the configured size.
	PageSize int

	// Custom indicates that the date fields are open for the applied fixed search.
	Custom bool
}

// FilterOption pairs a form value with its localized label.
type FilterOption struct {
	// Value is the browser form value.
	Value string

	// Label identifies the catalog text for the choice.
	Label string
}

// LogRow contains the table values and expandable details for a result.
type LogRow struct {
	// EventTime is the event timestamp in UTC, with its original precision.
	EventTime time.Time

	// ServiceName identifies the service that produced the log, when known.
	ServiceName string

	// Severity is the normalized level used for the table label and color.
	Severity string

	// ReportedSeverity preserves the level label supplied by the producing service.
	ReportedSeverity string

	// Message preserves the text of a nonblank string message.
	Message string

	// MessageLabel identifies the localized summary for an empty or structured message.
	MessageLabel string

	// TraceID is the hexadecimal trace identifier, when present.
	TraceID string

	// RelatedLogsURL opens the current search with the row's trace as a filter.
	RelatedLogsURL string

	// Match holds a preview of the first literal message match, when present.
	Match *MessageMatch

	// Details contains the fields shown when the row is expanded.
	Details LogDetails
}

// MessageMatch provides the parts of a message preview around the search text.
type MessageMatch struct {
	// Before is the visible context before the match.
	Before string

	// Text is the matching text as it appears in the original message.
	Text string

	// After is the visible context after the match.
	After string
}

// LogDetails holds the supplemental values displayed for a log entry.
type LogDetails struct {
	// Timing describes the timestamps and receipt offset shown in the inspector.
	Timing LogTiming

	// Request summarizes the HTTP or gRPC request reported by the log.
	Request RequestDetails

	// Body contains the original value, including structured and blank messages.
	Body LogValue

	// Environment is the deployment environment when supplied by the resource.
	Environment string

	// SpanID is the hexadecimal span identifier, when present.
	SpanID string

	// EventName is the producer's optional event name.
	EventName string

	// Attributes contains the record's attributes in their original order.
	Attributes []LogField

	// Resource describes the source, including resource attributes and metadata.
	Resource []LogField

	// Scope describes the instrumentation scope and its attributes.
	Scope []LogField

	// DroppedAttributes is the number of attributes the producer dropped.
	DroppedAttributes uint32

	// Flags contains the original OTLP log flags.
	Flags uint32
}

// LogTiming explains the selected event time and when the service received the log.
type LogTiming struct {
	// ObservedAt is the producer's observation time, or zero when absent.
	ObservedAt time.Time

	// ReceivedAt is the receipt timestamp in UTC, with its original precision.
	ReceivedAt time.Time

	// EventTimeLabel identifies the timestamp used as the event time.
	EventTimeLabel string

	// ReceiptOffset is the formatted absolute difference between event and receipt.
	ReceiptOffset string

	// ReceiptLabel identifies the label for an earlier, later or simultaneous receipt.
	ReceiptLabel string
}

// RequestDetails presents the status and duration reported by an HTTP or gRPC log.
type RequestDetails struct {
	// Status is the HTTP or gRPC status when identifiable from the attributes.
	Status string

	// StatusLabel identifies the protocol-specific status label.
	StatusLabel string

	// Duration is a formatted duration from a request log, when available.
	Duration string
}

// LogField represents a named metadata field or an attribute with its original key.
type LogField struct {
	// Name is the original attribute key, when this field is an attribute.
	Name string

	// Label is the catalog key for a known field, or empty for a literal key.
	Label string

	// Value is the scalar or expandable value associated with the field.
	Value LogValue
}

// LogValue presents an OTLP value as selectable text or as an expandable collection.
type LogValue struct {
	// Text is the display value for a scalar, with string whitespace preserved.
	Text string

	// Label identifies a collection type, an encoded value, or a blank value.
	Label string

	// Items contains the elements of a list in their original order.
	Items []LogValue

	// Fields contains the entries of a map in their original order.
	Fields []LogField
}
