package controller

import (
	"encoding/hex"

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

var severityOptions = []model.FilterOption{
	{Value: "DEBUG", Label: "logs.level.debug"},
	{Value: "INFO", Label: "logs.level.info"},
	{Value: "WARN", Label: "logs.level.warn"},
	{Value: "ERROR", Label: "logs.level.error"},
	{Value: "FATAL", Label: "logs.level.fatal"},
}

func newLogsModel(ctx context.Context, query storage.Query, results *storage.Page, maxRange time.Duration) (*model.Logs, error) {
	viewModel := &model.Logs{
		QueryURL: logsURL(query),
		Filters: model.Filters{
			StartTime:       query.StartTime.UTC(),
			EndTime:         query.EndTime.UTC(),
			ServiceName:     query.Service,
			MessageText:     query.Text,
			Severity:        query.Severity,
			TraceID:         query.TraceID,
			SeverityOptions: severityOptions,
			Windows:         windowOptions(maxRange),
			PageSize:        query.PageSize,
		},
		Rows: make([]model.LogRow, 0, len(results.Logs)),
	}
	for _, stored := range results.Logs {
		if err := ctx.Err(); err != nil {
			return nil, err
		}

		row, err := newLogRow(stored)
		if err != nil {
			return nil, err
		}
		viewModel.Rows = append(viewModel.Rows, row)
	}

	if !strings.IsEmpty(results.NextPageToken) {
		query.PageToken = results.NextPageToken
		viewModel.NextURL = logsURL(query)
	}
	return viewModel, nil
}

func newLogRow(stored *storage.Log) (model.LogRow, error) {
	var entry logs.LogRecord
	var source logs.ResourceLogs
	decoder := proto.NewJSON()

	if err := decoder.Decode(bytes.NewReader(stored.Record), &entry, codec.WithDiscardUnknown()); err != nil {
		return model.LogRow{}, err
	}

	if err := decoder.Decode(bytes.NewReader(stored.Resource), &source, codec.WithDiscardUnknown()); err != nil {
		return model.LogRow{}, err
	}

	severity := strings.Empty
	if level := entry.GetSeverityNumber(); level != logs.SeverityNumber_SEVERITY_NUMBER_UNSPECIFIED {
		severity = strings.TrimPrefix(level.String(), "SEVERITY_NUMBER_")
	}
	message, messageLabel := logMessage(entry.GetBody())

	// The inspector shows the stored text verbatim, including exact typed values.
	return model.LogRow{
		EventTime:        stored.EventTime.UTC(),
		ServiceName:      serviceName(source.GetResource().GetAttributes()),
		Severity:         severity,
		ReportedSeverity: entry.GetSeverityText(),
		Message:          message,
		MessageLabel:     messageLabel,
		TraceID:          hex.EncodeToString(entry.GetTraceId()),
		Details: model.LogDetails{
			ReceivedAt:      stored.ReceiveTime.UTC(),
			Entry:           string(stored.Record),
			Source:          string(stored.Resource),
			Instrumentation: string(stored.Scope),
		},
	}, nil
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

func serviceName(attributes []*common.KeyValue) string {
	for _, attribute := range attributes {
		if attribute.GetKey() != "service.name" {
			continue
		}
		if name, ok := attribute.GetValue().GetValue().(*common.AnyValue_StringValue); ok {
			return name.StringValue
		}
	}
	return strings.Empty
}
