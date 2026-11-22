package logs

import (
	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/einblick/internal/logs/archive/staging"
	"github.com/alexfalkowski/einblick/internal/logs/archive/worker"
	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/go-signal/v2"
)

// Module wires log storage, optional staging and optional R2 publication.
var Module = signal.Module(
	storage.Module,
	signal.Constructor(staging.NewWorkspace, newArchiveStore, archive.NewService),
	worker.Module,
)
