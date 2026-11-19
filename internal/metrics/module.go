package metrics

import (
	"github.com/alexfalkowski/einblick/internal/metrics/transport/grpc"
	"github.com/alexfalkowski/go-signal/v2"
)

// Module registers the development-only OTLP metric receiver with the shared
// transport. It provides no persistent storage.
var Module = signal.Module(
	signal.Constructor(grpc.NewServer),
	signal.Register(grpc.Register),
)
