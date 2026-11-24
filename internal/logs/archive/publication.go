package archive

import (
	"iter"

	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/io"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
)

// Publication is a batch whose remote object or local cleanup needs work.
type Publication struct {
	StagedBatch

	// PublishedChecksum is set once the remote object has been verified.
	PublishedChecksum string
}

// ObjectStore provides immutable archive objects for publication and queries.
type ObjectStore interface {
	// Checksum verifies the stored object's contents and returns its SHA-256.
	// An absent object returns an empty checksum.
	Checksum(ctx context.Context, key string) (string, error)

	// Create streams a file under key, failing if the key already exists.
	Create(ctx context.Context, key, checksum string, file io.Reader, size int64) error

	// List yields objects in key order under prefix and after startAfter.
	// It stops on the first error.
	List(ctx context.Context, prefix, startAfter string) iter.Seq2[Object, error]

	// URI returns the DuckDB location for a validated object key.
	URI(key string) string

	// Retention returns the configured object-age expiration duration.
	Retention() time.Duration

	// CheckPublication verifies the stored bytes and returns the object's timestamp.
	CheckPublication(ctx context.Context, key, checksum string) (time.Time, error)
}

func (s *service) Evict(ctx context.Context, today time.Time) (string, error) {
	if s.objects == nil {
		return strings.Empty, nil
	}

	batch, err := s.eviction.NextEviction(ctx, LocalWindowStart(today))
	if err != nil || strings.IsEmpty(batch.ID) {
		return strings.Empty, err
	}

	storedAt, err := s.objects.CheckPublication(ctx, batch.Key(), batch.PublishedChecksum)
	if err != nil {
		return batch.ID, err
	}

	return batch.ID, s.eviction.Evict(ctx, batch.ID, storedAt)
}

func (s *service) Publish(ctx context.Context) (string, error) {
	return s.processPublication(ctx, true)
}

func (s *service) ReconcilePublication(ctx context.Context) (string, error) {
	return s.processPublication(ctx, false)
}

func (s *service) processPublication(ctx context.Context, allowUpload bool) (string, error) {
	if s.objects == nil {
		return strings.Empty, nil
	}

	var next func(context.Context) (Publication, error)
	if allowUpload {
		next = s.batches.NextPublication
	} else {
		next = s.batches.NextReconciliation
	}
	batch, err := next(ctx)
	if err != nil || strings.IsEmpty(batch.ID) {
		return strings.Empty, err
	}

	if strings.IsEmpty(batch.PublishedChecksum) {
		confirmed, err := s.publish(ctx, batch.StagedBatch, allowUpload)
		if err != nil {
			return batch.ID, err
		}
		if !confirmed {
			return strings.Empty, nil
		}
	}

	if err := s.files.Remove(batch.Batch); err != nil {
		return batch.ID, err
	}
	return batch.ID, s.batches.FinishCleanup(ctx, batch.ID)
}

func (s *service) publish(ctx context.Context, batch StagedBatch, allowUpload bool) (bool, error) {
	key := batch.Key()

	checksum, err := s.objects.Checksum(ctx, key)
	if err != nil {
		return false, err
	}
	if !strings.IsEmpty(checksum) {
		return s.confirm(ctx, batch.ID, checksum)
	}
	if !allowUpload || strings.IsEmpty(batch.Checksum) {
		return false, nil
	}

	file, size, err := s.files.OpenVerified(ctx, batch)
	if err != nil {
		return false, err
	}
	if file == nil {
		// Keep repairs in publication order so a blocked repair leaves the
		// export slot available for batches of newly accepted logs.
		return false, s.stage(ctx, batch.Batch)
	}
	defer file.Close()

	// A negative HEAD can race an earlier request that is still committing.
	// Keep its checksum across regeneration and use conditional creation.
	if err := s.batches.RecordUpload(ctx, batch.ID, batch.Checksum); err != nil {
		return false, err
	}

	if err := s.objects.Create(ctx, key, batch.Checksum, file, size); err != nil {
		return false, err
	}

	checksum, err = s.objects.Checksum(ctx, key)
	if err != nil {
		return false, err
	}

	return s.confirm(ctx, batch.ID, checksum)
}

func (s *service) confirm(ctx context.Context, id, checksum string) (bool, error) {
	known, err := s.batches.HasUpload(ctx, id, checksum)
	if err != nil {
		return false, err
	}
	if !known {
		return false, errors.New("remote log archive does not match a recorded upload")
	}

	if err := s.batches.ConfirmPublication(ctx, id, checksum); err != nil {
		return false, err
	}
	return true, nil
}
