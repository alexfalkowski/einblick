package logs

import (
	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/einblick/internal/logs/transport/grpc"
	"github.com/alexfalkowski/go-signal/v2"
)

// Module registers the commit-backed OTLP log receiver with the shared transport.
var Module = signal.Module(
	storage.Module,
	signal.Constructor(grpc.NewServer),
	signal.Register(grpc.Register),
)
