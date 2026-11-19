package grpc

import (
	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/net/grpc/codes"
	"github.com/alexfalkowski/go-service/v3/net/grpc/status"
	v1 "go.opentelemetry.io/proto/otlp/collector/logs/v1"
)

// Export acknowledges a complete local commit. Temporary capacity, statement
// and commit failures are retryable; invalid protobuf content is permanent.
// Empty exports succeed without writing. No partial success is returned because
// this schema supports all decoded fields and writes the export atomically.
func (s *Server) Export(ctx context.Context, req *v1.ExportLogsServiceRequest) (*v1.ExportLogsServiceResponse, error) {
	_, err := s.repository.Add(ctx, req)
	if err != nil {
		switch {
		case errors.Is(err, storage.ErrInvalidLog):
			return nil, status.Error(codes.InvalidArgument, "logs: invalid protobuf content")
		case errors.Is(err, context.Canceled):
			return nil, status.Error(codes.Canceled, "logs: export cancelled")
		case errors.Is(err, context.DeadlineExceeded):
			return nil, status.Error(codes.DeadlineExceeded, "logs: export deadline exceeded")
		default:
			return nil, status.Error(codes.Unavailable, "logs: local commit unavailable; retry the export")
		}
	}
	return &v1.ExportLogsServiceResponse{}, nil
}
