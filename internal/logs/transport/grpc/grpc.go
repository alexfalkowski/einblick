package grpc

import (
	"github.com/alexfalkowski/go-service/v3/net/grpc"
	"github.com/alexfalkowski/go-service/v3/telemetry/logger"
	v1 "go.opentelemetry.io/proto/otlp/collector/logs/v1"
)

// Register attaches the standard OTLP logs service to the configured server.
func Register(registrar grpc.ServiceRegistrar, server *Server) {
	v1.RegisterLogsServiceServer(registrar, server)
}

// NewServer constructs the print-only receiver with the service logger.
func NewServer(logger *logger.Logger) *Server {
	return &Server{logger: logger}
}

// Server implements standard OTLP/gRPC log receipt for local development.
// Successful exports are printed and discarded; they are never stored.
type Server struct {
	// UnimplementedLogsServiceServer preserves upstream forward compatibility.
	v1.UnimplementedLogsServiceServer
	logger *logger.Logger
}
