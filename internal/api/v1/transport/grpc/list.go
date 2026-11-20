package grpc

import (
	v1 "github.com/alexfalkowski/einblick/api/einblick/v1"
	"github.com/alexfalkowski/go-service/v3/context"
)

// ListLogs delegates the typed request and maps failures to safe gRPC errors.
func (s *Server) ListLogs(ctx context.Context, req *v1.ListLogsRequest) (*v1.ListLogsResponse, error) {
	resp, err := s.logs.ListLogs(ctx, req)
	if err != nil {
		return nil, s.error(err)
	}
	return resp, nil
}
