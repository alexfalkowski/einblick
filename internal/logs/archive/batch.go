package archive

import (
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/id/uuid"
	"github.com/alexfalkowski/go-service/v3/io"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
)

// Version is the archive projection and key prefix.
const Version = "v1"

// DayLayout is the UTC date in v1 object keys.
const DayLayout = "2006-01-02"

const parquetExtension = ".parquet"

// Batch identifies an immutable set of logs for one UTC event day.
type Batch struct {
	// ID stays the same when a batch is retried.
	ID string

	// Day is the UTC event day in YYYY-MM-DD form.
	Day string

	// ContentDigest identifies the logical records independently of file encoding.
	ContentDigest string
}

// Path is the batch's stable path relative to the archive version.
func (b Batch) Path() string {
	return strings.Concat(dayPath(b.Day), b.ID, parquetExtension)
}

// Key is the complete object key for the batch.
func (b Batch) Key() string {
	return strings.Concat(Version, "/", b.Path())
}

func dayPath(day string) string {
	return strings.Concat("signal=logs/day=", day, "/")
}

func isBatchFilename(filename string) bool {
	if !strings.HasSuffix(filename, parquetExtension) {
		return false
	}

	batchID := strings.TrimSuffix(filename, parquetExtension)
	id, err := uuid.Parse(batchID)
	return err == nil && id.String() == batchID
}

// StagedBatch pairs a batch with the checksum recorded for its completed file.
type StagedBatch struct {
	Batch

	// Checksum identifies the bytes of the completed Parquet file.
	Checksum string
}

// Backlog describes accepted records awaiting publication and the latest confirmed publication.
type Backlog struct {
	// OldestReceivedAt is the earliest pending receipt time, or zero when the backlog is empty.
	OldestReceivedAt time.Time

	// LastPublishedAt is the latest known UTC confirmation time, the Unix epoch
	// before any publication, or nil when only legacy confirmation times exist.
	LastPublishedAt *time.Time

	// PendingRecords is the number of accepted records that are still awaiting publication.
	PendingRecords int64

	// PendingRecordBytes counts stored record JSON bytes, excluding shared OTLP headers.
	PendingRecordBytes int64
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

	// NextPublication selects one batch for cleanup, reconciliation or upload
	// and advances its position in the durable retry order.
	// A zero batch indicates no work.
	NextPublication(ctx context.Context) (Publication, error)

	// NextReconciliation advances the retry order for one batch with pending
	// cleanup or a recorded upload attempt. A zero batch indicates no work.
	NextReconciliation(ctx context.Context) (Publication, error)

	// RecordUpload persists an attempted file checksum before the remote write.
	RecordUpload(ctx context.Context, id, checksum string) error

	// HasUpload reports whether an object checksum matches an attempted write.
	HasUpload(ctx context.Context, id, checksum string) (bool, error)

	// ConfirmPublication records the verified remote checksum before file cleanup.
	ConfirmPublication(ctx context.Context, id, checksum string) error

	// FinishCleanup records completion and clears the staged-file checksum.
	FinishCleanup(ctx context.Context, id string) error
}

// EvictionRepository selects and removes eligible complete local batches.
type EvictionRepository interface {
	// NextEviction advances the retry order for one confirmed and cleaned batch
	// whose rows predate cutoff. A zero batch indicates no eligible work.
	NextEviction(ctx context.Context, cutoff time.Time) (Publication, error)

	// Evict removes the selected batch's source rows and records the verified object timestamp atomically.
	Evict(ctx context.Context, id string, storedAt time.Time) error
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

	// OpenVerified opens the verified file at its start, or returns a nil
	// reader if the file needs regeneration. The caller closes the reader.
	OpenVerified(ctx context.Context, batch StagedBatch) (io.ReadCloser, int64, error)

	// Remove releases a confirmed batch's local file. An absent file is already clean.
	Remove(batch Batch) error
}
