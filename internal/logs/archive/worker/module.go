package worker

import (
	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/go-signal/v2"
)

// Module runs the archive service on a periodic timer through the server lifecycle.
var Module = signal.Module(signal.Register(register))

func register(lc signal.Lifecycle, cfg *archive.Config, service archive.Service) {
	if cfg == nil {
		return
	}

	w := &worker{service: service, interval: cfg.Interval}
	lc.Append(signal.Hook{
		OnStart: w.start,
		OnStop:  w.stop,
	})
}
