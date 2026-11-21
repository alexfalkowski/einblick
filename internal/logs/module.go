package logs

import (
	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/einblick/internal/logs/archive/staging"
	"github.com/alexfalkowski/einblick/internal/logs/archive/worker"
	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/go-signal/v2"
)

// Module wires log storage and optional local archival.
var Module = signal.Module(
	storage.Module,
	signal.Constructor(staging.NewWorkspace, archive.NewService),
	worker.Module,
)
