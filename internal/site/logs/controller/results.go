package controller

import (
	"encoding/hex"
	"unicode/utf8"

	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/einblick/internal/site/logs/model"
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

var severityOptions = []model.FilterOption{
	{Value: "DEBUG", Label: "logs.level.debug"},
	{Value: "INFO", Label: "logs.level.info"},
	{Value: "WARN", Label: "logs.level.warn"},
	{Value: "ERROR", Label: "logs.level.error"},
	{Value: "FATAL", Label: "logs.level.fatal"},
}

func newLogsModel(
	ctx context.Context, query storage.Query, results *storage.Page, recent string, maxRange time.Duration,
) (*model.Logs, error) {
	windows, selectedWindow := windowOptions(maxRange, time.Duration(query.EndTime.Sub(query.StartTime)))
	viewModel := &model.Logs{
		QueryURL: logsURL(query, strings.Empty),
		Filters: model.Filters{
			StartTime:       query.StartTime.UTC(),
			EndTime:         query.EndTime.UTC(),
			ServiceName:     query.Service,
			MessageText:     query.Text,
			Severity:        query.Severity,
			TraceID:         query.TraceID,
			SeverityOptions: severityOptions,
			Windows:         windows,
			SelectedWindow:  selectedWindow,
			RecentWindow:    recent,
			PageSize:        query.PageSize,
		},
		Rows: make([]model.LogRow, 0, len(results.Logs)),
	}
	for _, stored := range results.Logs {
		if err := ctx.Err(); err != nil {
			return nil, err
		}

		row, err := newLogRow(stored, query.Text)
		if err != nil {
			return nil, err
		}

		if storage.ValidTraceID(row.TraceID) {
			related := query
			related.TraceID, related.PageToken = row.TraceID, strings.Empty
			row.RelatedLogsURL = logsURL(related, strings.Empty)
		}

		viewModel.Rows = append(viewModel.Rows, row)
	}

	if !strings.IsEmpty(results.NextPageToken) {
		query.PageToken = results.NextPageToken
		viewModel.NextURL = logsURL(query, recent)
	}
	return viewModel, nil
}

func newLogRow(stored *storage.Log, search string) (model.LogRow, error) {
	var entry logs.LogRecord
	var source logs.ResourceLogs
	var scope logs.ScopeLogs
	decoder := proto.NewJSON()

	if err := decoder.Decode(bytes.NewReader(stored.Record), &entry, codec.WithDiscardUnknown()); err != nil {
		return model.LogRow{}, err
	}

	if err := decoder.Decode(bytes.NewReader(stored.Resource), &source, codec.WithDiscardUnknown()); err != nil {
		return model.LogRow{}, err
	}

	if err := decoder.Decode(bytes.NewReader(stored.Scope), &scope, codec.WithDiscardUnknown()); err != nil {
		return model.LogRow{}, err
	}

	var severity string
	if level := entry.GetSeverityNumber(); level != logs.SeverityNumber_SEVERITY_NUMBER_UNSPECIFIED {
		severity = strings.TrimPrefix(level.String(), "SEVERITY_NUMBER_")
	} else {
		severity = strings.Empty
	}
	message, messageLabel := logMessage(entry.GetBody())

	return model.LogRow{
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

func messageMatch(message, search string) *model.MessageMatch {
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
	return &model.MessageMatch{Before: prefix, Text: search, After: suffix}
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
