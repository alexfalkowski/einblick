package grpc

import (
	"github.com/alexfalkowski/go-service/v3/bytes"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/encoding/proto"
	"github.com/alexfalkowski/go-service/v3/net/grpc/codes"
	"github.com/alexfalkowski/go-service/v3/net/grpc/status"
	"github.com/alexfalkowski/go-service/v3/telemetry/logger"
	v1 "go.opentelemetry.io/proto/otlp/collector/logs/v1"
)

// Export prints the Protobuf JSON payload through the service logger.
// Success means receipt only; the records are discarded after printing.
func (s *Server) Export(ctx context.Context, req *v1.ExportLogsServiceRequest) (*v1.ExportLogsServiceResponse, error) {
	var payload bytes.Buffer
	if err := proto.NewJSON().Encode(&payload, req); err != nil {
		return nil, status.Error(codes.InvalidArgument, "logs: invalid log payload")
	}
	s.logger.Log(ctx, logger.NewText(payload.String()), logger.String("signal", "logs"))

	return &v1.ExportLogsServiceResponse{}, nil
}
