package telemetry

import (
	"context"
	"sync/atomic"

	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/telemetry/metrics"
	"github.com/alexfalkowski/go-service/v3/time"
	"github.com/alexfalkowski/go-sync"
)

func startBacklogMetrics(ctx context.Context, params RegisterParams) (func(context.Context) error, error) {
	var snapshot atomic.Pointer[archive.Backlog]
	registration, err := registerBacklogMetrics(params.Meter, snapshot.Load)
	if err != nil {
		return nil, err
	}

	// Sampling continues after go-signal cancels the startup context.
	lifetime, cancel := context.WithCancel(context.WithoutCancel(ctx))
	readBacklog := logBacklog(params.Archive.Backlog, params.Logger)
	sampleBacklog := func(ctx context.Context) *archive.Backlog {
		readCtx, cancelRead := context.WithTimeout(ctx, params.Queries.Timeout.Duration())
		defer cancelRead()

		backlog, err := readBacklog(readCtx)
		if err != nil {
			return nil
		}
		return &backlog
	}

	task := sync.Go(lifetime, func(ctx context.Context) error {
		delay := params.Config.Interval
		for ctx.Err() == nil {
			select {
			case <-ctx.Done():
				return nil
			case <-time.After(delay):
			}

			started := time.Now()
			snapshot.Store(sampleBacklog(ctx))
			delay = max(params.Config.Interval, time.Since(started))
		}
		return nil
	})

	stopSampling := func() error {
		defer cancel()
		return registration.Unregister()
	}

	return func(ctx context.Context) error {
		return errors.Join(stopSampling(), task.Await(ctx))
	}, nil
}

func registerBacklogMetrics(meter metrics.Meter, loadBacklog func() *archive.Backlog) (metrics.Registration, error) {
	pending, err := meter.Int64ObservableGauge("log_archive.pending.records",
		metrics.WithUnit("{record}"), metrics.WithDescription("Accepted log records awaiting archive publication"))
	if err != nil {
		return nil, err
	}

	pendingBytes, err := meter.Int64ObservableGauge("log_archive.pending.size",
		metrics.WithUnit("By"), metrics.WithDescription("Stored JSON bytes of pending log records"))
	if err != nil {
		return nil, err
	}

	age, err := meter.Int64ObservableGauge("log_archive.pending.oldest_age",
		metrics.WithUnit("s"), metrics.WithDescription("Age of the oldest pending log record since receipt"))
	if err != nil {
		return nil, err
	}

	last, err := meter.Int64ObservableGauge("log_archive.last_publication.timestamp",
		metrics.WithUnit("s"), metrics.WithDescription("Unix timestamp of the last confirmed archive publication"))
	if err != nil {
		return nil, err
	}

	return meter.RegisterCallback(func(_ context.Context, observer metrics.Observer) error {
		if backlog := loadBacklog(); backlog != nil {
			var ageSeconds int64
			if !backlog.OldestReceivedAt.IsZero() {
				ageSeconds = int64(max(time.Since(backlog.OldestReceivedAt), 0) / time.Second)
			}
			observer.ObserveInt64(pending, backlog.PendingRecords)
			observer.ObserveInt64(pendingBytes, backlog.PendingRecordBytes)
			observer.ObserveInt64(age, ageSeconds)
			if backlog.LastPublishedAt != nil {
				observer.ObserveInt64(last, backlog.LastPublishedAt.Unix())
			}
		}
		// Preserve the export of unrelated metrics when backlog storage is unavailable.
		return nil
	}, pending, pendingBytes, age, last)
}
