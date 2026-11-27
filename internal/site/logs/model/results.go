package model

import (
	"encoding/hex"
	"unicode/utf8"

	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/einblick/internal/site/logs/query"
	"github.com/alexfalkowski/einblick/internal/site/timerange"
	"github.com/alexfalkowski/go-service/v3/bytes"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/encoding/codec"
	"github.com/alexfalkowski/go-service/v3/encoding/proto"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
	common "go.opentelemetry.io/proto/otlp/common/v1"
	logs "go.opentelemetry.io/proto/otlp/logs/v1"
)

const matchContextRunes = 12

var severityOptions = []FilterOption{
	{Value: "DEBUG", Label: "logs.level.debug"},
	{Value: "INFO", Label: "logs.level.info"},
	{Value: "WARN", Label: "logs.level.warn"},
	{Value: "ERROR", Label: "logs.level.error"},
	{Value: "FATAL", Label: "logs.level.fatal"},
}

// NewLogs builds the view model for a page of logs.
func NewLogs(ctx context.Context, search query.Search, results *storage.Page, now time.Time, limits timerange.Limits) (*Logs, error) {
	filters := search.Query()
	maxRange := limits.PresetLimit()
	windows, selectedWindow := search.Time.Presets(maxRange)
	viewModel := &Logs{
		QueryURL:    search.ReloadURL(maxRange),
		ActivityURL: search.ActivityURL(),
		NextURL:     search.NextURL(results.NextPageToken),
		Filters: Filters{
			Custom:          search.Custom,
			Earliest:        limits.Earliest(now),
			StartTime:       filters.StartTime,
			EndTime:         filters.EndTime,
			ServiceName:     filters.Service,
			MessageText:     filters.Text,
			Severity:        filters.Severity,
			TraceID:         filters.TraceID,
			SeverityOptions: severityOptions,
			Windows:         windows,
			SelectedWindow:  selectedWindow,
			RecentWindow:    search.Time.SearchWindow,
			PageSize:        filters.PageSize,
		},
		Rows: make([]LogRow, 0, len(results.Logs)),
	}
	for _, stored := range results.Logs {
		if err := ctx.Err(); err != nil {
			return nil, err
		}

		row, err := newLogRow(stored, filters.Text)
		if err != nil {
			return nil, err
		}

		row.RelatedLogsURL = search.RelatedLogsURL(row.TraceID)
		viewModel.Rows = append(viewModel.Rows, row)
	}
	return viewModel, nil
}

func newLogRow(stored *storage.Log, search string) (LogRow, error) {
	var entry logs.LogRecord
	var source logs.ResourceLogs
	var scope logs.ScopeLogs
	decoder := proto.NewJSON()

	if err := decoder.Decode(bytes.NewReader(stored.Record), &entry, codec.WithDiscardUnknown()); err != nil {
		return LogRow{}, err
	}

	if err := decoder.Decode(bytes.NewReader(stored.Resource), &source, codec.WithDiscardUnknown()); err != nil {
		return LogRow{}, err
	}

	if err := decoder.Decode(bytes.NewReader(stored.Scope), &scope, codec.WithDiscardUnknown()); err != nil {
		return LogRow{}, err
	}

	var severity string
	if level := entry.GetSeverityNumber(); level != logs.SeverityNumber_SEVERITY_NUMBER_UNSPECIFIED {
		severity = strings.TrimPrefix(level.String(), "SEVERITY_NUMBER_")
	} else {
		severity = strings.Empty
	}
	message, messageLabel := logMessage(entry.GetBody())

	return LogRow{
		EventTime:        stored.EventTime.UTC(),
		ServiceName:      stringAttribute(source.GetResource().GetAttributes(), "service.name"),
		Severity:         severity,
		ReportedSeverity: entry.GetSeverityText(),
		Message:          message,
		MessageLabel:     messageLabel,
		Match:            messageMatch(message, search),
		TraceID:          hex.EncodeToString(entry.GetTraceId()),
		Details:          logDetails(stored, &entry, &source, &scope),
	}, nil
}

func messageMatch(message, search string) *MessageMatch {
	if strings.IsEmpty(search) {
		return nil
	}
	before, after, found := strings.Cut(message, search)
	if !found {
		return nil
	}

	start, end := len(before), 0
	for range matchContextRunes {
		_, left := utf8.DecodeLastRuneInString(before[:start])
		_, right := utf8.DecodeRuneInString(after[end:])
		start -= left
		end += right
	}

	prefix, suffix := before[start:], after[:end]
	if start > 0 {
		prefix = "…" + prefix
	}
	if end < len(after) {
		suffix += "…"
	}
	return &MessageMatch{Before: prefix, Text: search, After: suffix}
}

// logMessage returns the displayed text or a catalog key for its fallback.
func logMessage(body *common.AnyValue) (string, string) {
	if body == nil {
		return strings.Empty, "logs.no_body"
	}

	text, ok := body.GetValue().(*common.AnyValue_StringValue)
	if !ok {
		return strings.Empty, "logs.structured_body"
	}
	if strings.IsEmpty(strings.TrimSpace(text.StringValue)) {
		return strings.Empty, "logs.no_body"
	}
	return text.StringValue, strings.Empty
}

func stringAttribute(attributes []*common.KeyValue, key string) string {
	for _, attribute := range attributes {
		if attribute.GetKey() != key {
			continue
		}

		if value, ok := attribute.GetValue().GetValue().(*common.AnyValue_StringValue); ok {
			return value.StringValue
		}
	}
	return strings.Empty
}
