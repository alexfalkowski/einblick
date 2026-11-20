package v1

import (
	"github.com/alexfalkowski/einblick/internal/api/v1/logs"
	"github.com/alexfalkowski/einblick/internal/api/v1/transport/grpc"
	"github.com/alexfalkowski/einblick/internal/api/v1/transport/http"
	"github.com/alexfalkowski/go-signal/v2"
)

// Module registers the v1 query service with the shared gRPC and HTTP servers.
var Module = signal.Module(
	logs.Module,
	signal.Constructor(grpc.NewServer),
	signal.Constructor(http.NewServer),
	signal.Register(grpc.Register),
	signal.Register(http.Register),
)
