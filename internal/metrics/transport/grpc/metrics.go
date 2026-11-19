package grpc

import (
	"github.com/alexfalkowski/go-service/v3/bytes"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/encoding/proto"
	"github.com/alexfalkowski/go-service/v3/net/grpc/codes"
	"github.com/alexfalkowski/go-service/v3/net/grpc/status"
	"github.com/alexfalkowski/go-service/v3/telemetry/logger"
	v1 "go.opentelemetry.io/proto/otlp/collector/metrics/v1"
)

// Export prints the Protobuf JSON payload through the service logger.
// Success means receipt only; the records are discarded after printing.
func (s *Server) Export(ctx context.Context, req *v1.ExportMetricsServiceRequest) (*v1.ExportMetricsServiceResponse, error) {
	var payload bytes.Buffer
	if err := proto.NewJSON().Encode(&payload, req); err != nil {
		return nil, status.Error(codes.InvalidArgument, "metrics: invalid metric payload")
	}
	s.logger.Log(ctx, logger.NewText(payload.String()), logger.String("signal", "metrics"))

	return &v1.ExportMetricsServiceResponse{}, nil
}
