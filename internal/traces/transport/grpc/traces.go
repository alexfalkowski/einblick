package grpc

import (
	"github.com/alexfalkowski/go-service/v3/bytes"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/encoding/proto"
	"github.com/alexfalkowski/go-service/v3/net/grpc/codes"
	"github.com/alexfalkowski/go-service/v3/net/grpc/status"
	"github.com/alexfalkowski/go-service/v3/telemetry/logger"
	v1 "go.opentelemetry.io/proto/otlp/collector/trace/v1"
)

// Export prints the Protobuf JSON payload through the service logger.
// Success means receipt only; the records are discarded after printing.
func (s *Server) Export(ctx context.Context, req *v1.ExportTraceServiceRequest) (*v1.ExportTraceServiceResponse, error) {
	var payload bytes.Buffer
	if err := proto.NewJSON().Encode(&payload, req); err != nil {
		return nil, status.Error(codes.InvalidArgument, "traces: invalid trace payload")
	}
	s.logger.Log(ctx, logger.NewText("OTLP traces received (development only; discarded)"), logger.String("payload", payload.String()))

	return &v1.ExportTraceServiceResponse{}, nil
}
