package grpc

import (
	v1 "github.com/alexfalkowski/einblick/api/einblick/v1"
	"github.com/alexfalkowski/einblick/internal/api/v1/logs"
	"github.com/alexfalkowski/go-service/v3/net/grpc"
)

// Register adds the generated query contract to the shared gRPC server.
func Register(registrar grpc.ServiceRegistrar, server *Server) {
	v1.RegisterServiceServer(registrar, server)
}

// NewServer delegates query behavior to the shared versioned operation.
func NewServer(logs *logs.Service) *Server {
	return &Server{logs: logs}
}

// Server adapts the query operation to gRPC requests and status errors.
type Server struct {
	// UnimplementedServiceServer preserves generated forward compatibility.
	v1.UnimplementedServiceServer
	logs *logs.Service
}
