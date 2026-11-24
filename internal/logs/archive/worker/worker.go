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

func (w *worker) start(ctx context.Context) error {
	if err := w.service.Prepare(); err != nil {
		return err
	}

	// go-signal cancels the startup context after the start hooks finish.
	runCtx, cancel := context.WithCancel(context.WithoutCancel(ctx))
	w.cancel = cancel
	w.task = sync.Go(runCtx, w.run)
	return nil
}

func (w *worker) stop(ctx context.Context) error {
	w.cancel()
	return w.task.Await(ctx)
}

func (w *worker) run(ctx context.Context) error {
	var recovered bool
	return signal.Timer(ctx, w.interval.Duration(), func(ctx context.Context) error {
		today := archive.DayStart(time.Now())
		recovered = recovered || w.service.Recover(ctx) == nil
		if recovered {
			_, _ = w.service.Export(ctx, today)
			_, _ = w.service.Publish(ctx)
		} else {
			_, _ = w.service.ReconcilePublication(ctx)
		}

		_, _ = w.service.Evict(ctx, today)
		return nil
	})
}
