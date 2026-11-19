package logs

import (
	"github.com/alexfalkowski/einblick/internal/logs/transport/grpc"
	"github.com/alexfalkowski/go-signal/v2"
)

// Module registers the development-only OTLP log receiver with the shared
// transport. It provides no persistent storage.
var Module = signal.Module(
	signal.Constructor(grpc.NewServer),
	signal.Register(grpc.Register),
)
