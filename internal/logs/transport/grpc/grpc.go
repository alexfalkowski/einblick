package grpc

import (
	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/go-service/v3/net/grpc"
	v1 "go.opentelemetry.io/proto/otlp/collector/logs/v1"
)

// Register attaches the standard OTLP logs service to the configured server.
func Register(registrar grpc.ServiceRegistrar, server *Server) {
	v1.RegisterLogsServiceServer(registrar, server)
}

// NewServer constructs the receiver over the service's composed log repository.
func NewServer(repository storage.Repository) *Server {
	return &Server{repository: repository}
}

// Server acknowledges standard OTLP/gRPC logs after successful local commit.
type Server struct {
	// UnimplementedLogsServiceServer preserves upstream forward compatibility.
	v1.UnimplementedLogsServiceServer
	repository storage.Repository
}
