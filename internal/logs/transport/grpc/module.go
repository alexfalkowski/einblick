package grpc

import "github.com/alexfalkowski/go-signal/v2"

// Module registers the commit-backed OTLP log receiver with the shared gRPC transport.
var Module = signal.Module(
	signal.Constructor(NewServer),
	signal.Register(Register),
)
