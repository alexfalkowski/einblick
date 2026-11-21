package archive

import "github.com/alexfalkowski/go-service/v3/context"

// Batch identifies an immutable set of logs for one UTC event day.
type Batch struct {
	// ID stays the same when a batch is retried.
	ID string

	// Day is the UTC event day in YYYY-MM-DD form.
	Day string

	// ContentDigest identifies the logical records independently of file encoding.
	ContentDigest string
}

// StagedBatch pairs a batch with the checksum recorded for its completed file.
type StagedBatch struct {
	Batch

	// Checksum identifies the bytes of the completed Parquet file.
	Checksum string
}

// BatchRepository owns batch membership and durable staging state.
type BatchRepository interface {
	// Next returns the oldest pending batch or claims new work using the target
	// source byte size. A zero batch means there is no work to stage.
	Next(ctx context.Context, batchBytes int64) (Batch, error)

	// VisitCompleted streams batches recorded as staged and stops on a visitor
	// error. The visitor may requeue a batch that needs to be staged again.
	VisitCompleted(ctx context.Context, visit func(StagedBatch) error) error

	// Complete records the checksum of the closed, verified file.
	Complete(ctx context.Context, id, checksum string) error

	// Requeue makes the same batch and membership pending again.
	Requeue(ctx context.Context, id string) error
}

// BatchWriter produces and verifies Parquet for a claimed batch.
type BatchWriter interface {
	// WriteParquet writes to path and verifies the file's logical contents.
	WriteParquet(ctx context.Context, batch Batch, path string) error
}

// StagedFiles owns the local files produced from an immutable batch.
type StagedFiles interface {
	// Prepare checks the workspace and clears interrupted temporary output.
	Prepare() error

	// Verify reports whether the file still matches the recorded checksum.
	// A missing or mismatched file returns false for recovery.
	Verify(ctx context.Context, batch StagedBatch) (bool, error)

	// Stage creates the completed file and returns its checksum after verification.
	Stage(ctx context.Context, batch Batch) (string, error)
}
