package worker

import (
	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/time"
	"github.com/alexfalkowski/go-signal/v2"
	"github.com/alexfalkowski/go-sync"
)

type worker struct {
	service  archive.Service
	cancel   context.CancelFunc
	task     *sync.Task
	interval time.Duration
}

func (w *worker) start(_ context.Context) error {
	if err := w.service.Prepare(); err != nil {
		return err
	}

	runCtx, cancel := context.WithCancel(context.Background())
	w.cancel = cancel
	w.task = sync.Go(runCtx, w.run)
	return nil
}

func (w *worker) stop(ctx context.Context) error {
	w.cancel()
	return w.task.Await(ctx)
}

func (w *worker) run(ctx context.Context) error {
	recovered := false
	return signal.Timer(ctx, w.interval.Duration(), func(ctx context.Context) error {
		recovered = recovered || w.service.Recover(ctx) == nil
		if recovered {
			// A failed attempt leaves the durable job pending for the next tick.
			_, _ = w.service.Export(ctx)
		}
		return nil
	})
}
