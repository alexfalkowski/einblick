package logs

import (
	v1 "github.com/alexfalkowski/einblick/api/einblick/v1"
	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/go-service/v3/bytes"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/encoding/proto"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/meta"
	logs "go.opentelemetry.io/proto/otlp/logs/v1"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// ListLogs returns a latest-first page of complete OTLP records. Required
// timestamps are validated before conversion; storage owns bounds and filters.
func (s *Service) ListLogs(ctx context.Context, req *v1.ListLogsRequest) (*v1.ListLogsResponse, error) {
	if err := req.GetStartTime().CheckValid(); err != nil {
		return nil, errors.Join(storage.ErrInvalidQuery, err)
	}
	if err := req.GetEndTime().CheckValid(); err != nil {
		return nil, errors.Join(storage.ErrInvalidQuery, err)
	}

	page, err := s.repo.List(ctx, storage.Query{
		StartTime: req.GetStartTime().AsTime(), EndTime: req.GetEndTime().AsTime(),
		Service: req.GetService(), Severity: req.GetSeverity(), Text: req.GetText(),
		TraceID: req.GetTraceId(), PageSize: int(req.GetPageSize()), PageToken: req.GetPageToken(),
	})
	if err != nil {
		return nil, err
	}

	resp := &v1.ListLogsResponse{Meta: meta.Strings(ctx), NextPageToken: page.NextPageToken}
	for _, row := range page.Logs {
		log, err := storedLog(row)
		if err != nil {
			return nil, err
		}
		resp.Logs = append(resp.Logs, log)
	}
	return resp, nil
}

func storedLog(row *storage.Log) (*v1.Log, error) {
	log := &v1.Log{
		Id: row.ID, EventTime: timestamppb.New(row.EventTime), ReceiveTime: timestamppb.New(row.ReceiveTime),
		Resource: &logs.ResourceLogs{}, Scope: &logs.ScopeLogs{}, Record: &logs.LogRecord{},
	}
	encoder := proto.NewJSON()
	if err := encoder.Decode(bytes.NewReader(row.Resource), log.GetResource()); err != nil {
		return nil, err
	}
	if err := encoder.Decode(bytes.NewReader(row.Scope), log.GetScope()); err != nil {
		return nil, err
	}
	if err := encoder.Decode(bytes.NewReader(row.Record), log.GetRecord()); err != nil {
		return nil, err
	}
	return log, nil
}
