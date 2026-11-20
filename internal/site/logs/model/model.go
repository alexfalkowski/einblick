package model

import "github.com/alexfalkowski/go-service/v3/time"

// Logs contains the filters and results for the full and partial views.
type Logs struct {
	// NextURL continues the current search. It is empty on the last page.
	NextURL string

	// QueryURL identifies the current search with fixed, exact bounds.
	QueryURL string

	// Rows contains matching logs in newest-first order.
	Rows []LogRow

	// Filters contains the active selections as displayed in the form.
	Filters Filters
}

// Filters holds the display values for the log search form.
type Filters struct {
	// StartTime is the inclusive UTC bound displayed in the form and results.
	StartTime time.Time

	// EndTime is the exclusive UTC bound displayed in the form and results.
	EndTime time.Time

	// ServiceName is the exact selected service. Empty selects all services.
	ServiceName string

	// MessageText is the literal text to find within string log messages.
	MessageText string

	// Severity is the selected level. Empty selects all levels.
	Severity string

	// TraceID is the hexadecimal identifier selected for correlation.
	TraceID string

	// SeverityOptions lists the available levels in ascending severity order.
	SeverityOptions []FilterOption

	// Windows holds the recent ranges that fit the configured search limit.
	Windows []FilterOption

	// PageSize is the requested number of results. Zero uses the configured size.
	PageSize int
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

	// Details contains the text shown when the row is expanded.
	Details LogDetails
}

// LogDetails holds the supplemental values displayed for a log entry.
type LogDetails struct {
	// ReceivedAt is the receipt timestamp in UTC, with its original precision.
	ReceivedAt time.Time

	// Entry contains the original entry data as text.
	Entry string

	// Source contains the original context about the source of the log.
	Source string

	// Instrumentation contains the original context about the logging library.
	Instrumentation string
}
