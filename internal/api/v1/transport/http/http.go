package http

import (
	v1 "github.com/alexfalkowski/einblick/api/einblick/v1"
	"github.com/alexfalkowski/einblick/internal/api/v1/logs"
	"github.com/alexfalkowski/go-service/v3/net/http/rpc"
)

// Register exposes POST /einblick.v1.Service/ListLogs on the shared HTTP server.
func Register(server *Server) {
	server.Route(v1.Service_ListLogs_FullMethodName, server.ListLogs)
}

// NewServer delegates query behavior to the shared versioned operation.
func NewServer(server *rpc.Server, logs *logs.Service) *Server {
	return &Server{logs: logs, Server: server}
}

// Server adapts the query operation to HTTP RPC requests and safe errors.
type Server struct {
	logs *logs.Service

	// Server supplies shared routing, decoding and content negotiation.
	*rpc.Server
}
