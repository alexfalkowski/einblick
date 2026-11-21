package staging

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"os"
	"path/filepath"

	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/io"
	"github.com/alexfalkowski/go-service/v3/strings"
)

const (
	archiveVersion = "v1"
	logPartition   = "signal=logs"
	pendingDir     = ".pending"
	partialName    = ".logs.parquet.partial"
	directoryMode  = 0o700
)

// NewWorkspace manages local archive files under the configured workspace.
// A nil cfg disables staging.
func NewWorkspace(cfg *archive.Config, writer archive.BatchWriter) archive.StagedFiles {
	if cfg == nil {
		return nil
	}

	return &workspace{path: filepath.Join(cfg.Workspace, archiveVersion), writer: writer}
}

type workspace struct {
	writer   archive.BatchWriter
	prepared os.FileInfo
	path     string
}

// Prepare opens the provisioned export directory and clears interrupted output.
func (w *workspace) Prepare() error {
	root, info, err := w.openWorkspace()
	if err != nil {
		return err
	}
	defer root.Close()

	if info.Mode().Perm() != directoryMode {
		if err := root.Chmod(".", directoryMode); err != nil {
			return err
		}
	}
	if err := root.RemoveAll(pendingDir); err != nil {
		return err
	}
	if err := root.Mkdir(pendingDir, directoryMode); err != nil {
		return err
	}
	w.prepared = info
	return w.checkWorkspace(info)
}

// Verify checks the completed file against the checksum recorded for the batch.
// A missing file can be regenerated from the retained log rows.
func (w *workspace) Verify(ctx context.Context, b archive.StagedBatch) (bool, error) {
	root, info, err := w.openWorkspace()
	if err != nil {
		return false, err
	}
	defer root.Close()

	checksum, err := fileChecksum(ctx, root, batchPath(b.Batch))
	if workspaceErr := w.checkWorkspace(info); workspaceErr != nil {
		return false, workspaceErr
	}
	if errors.Is(err, io.ErrNotExist) {
		return false, nil
	}
	return checksum == b.Checksum, err
}

// Stage writes, verifies and publishes one completed file. It returns the file
// checksum for the caller to record in durable batch state.
func (w *workspace) Stage(ctx context.Context, b archive.Batch) (_ string, err error) {
	root, info, err := w.openWorkspace()
	if err != nil {
		return strings.Empty, err
	}
	defer root.Close()

	destination := batchPath(b)
	day := filepath.Dir(destination)
	// A pending batch can have a final filename after an interrupted rename
	// or a checksum mismatch. Its retained rows remain authoritative.
	if err := root.Remove(destination); err != nil && !errors.Is(err, io.ErrNotExist) {
		return strings.Empty, err
	}
	if err := root.MkdirAll(day, directoryMode); err != nil {
		return strings.Empty, err
	}

	// DuckDB opens its own pathname. Only the verified workspace has this
	// attempt's private directory, and COPY cannot create the parent directory.
	attempt := filepath.Join(pendingDir, rand.Text())
	if err := root.Mkdir(attempt, directoryMode); err != nil {
		return strings.Empty, err
	}
	defer func() {
		err = errors.Join(err, root.RemoveAll(attempt))
	}()

	partial := filepath.Join(attempt, partialName)
	if err := w.writer.WriteParquet(ctx, b, filepath.Join(w.path, partial)); err != nil {
		return strings.Empty, err
	}
	checksum, err := publishFile(ctx, root, partial, destination)
	if err != nil {
		return strings.Empty, err
	}
	return checksum, w.checkWorkspace(info)
}

func (w *workspace) openWorkspace() (*os.Root, os.FileInfo, error) {
	root, err := os.OpenRoot(w.path)
	if err != nil {
		return nil, nil, errors.Prefix("log archive workspace", err)
	}
	info, err := root.Stat(".")
	if err == nil {
		err = w.checkWorkspace(info)
	}
	if err != nil {
		root.Close()
		return nil, nil, err
	}
	return root, info, nil
}

func (w *workspace) checkWorkspace(opened os.FileInfo) error {
	current, err := os.Lstat(w.path)
	if err != nil {
		return errors.Prefix("log archive workspace", err)
	}
	if !os.SameFile(current, opened) || (w.prepared != nil && !os.SameFile(current, w.prepared)) {
		return errors.New("log archive workspace changed since startup")
	}
	return nil
}

func batchPath(b archive.Batch) string {
	return filepath.Join(logPartition, "day="+b.Day, b.ID+".parquet")
}

func publishFile(ctx context.Context, root *os.Root, partial, destination string) (string, error) {
	checksum, err := fileChecksum(ctx, root, partial)
	if err != nil {
		return strings.Empty, err
	}

	if err := syncPath(root, partial); err != nil {
		return strings.Empty, err
	}

	if err := root.Rename(partial, destination); err != nil {
		return strings.Empty, err
	}

	return checksum, syncPath(root, filepath.Dir(destination))
}

func fileChecksum(ctx context.Context, root *os.Root, path string) (string, error) {
	file, err := root.Open(path)
	if err != nil {
		return strings.Empty, err
	}
	defer file.Close()

	hash := sha256.New()
	if _, err := io.Copy(hash, contextReader{ctx: ctx, reader: file}); err != nil {
		return strings.Empty, err
	}
	return hex.EncodeToString(hash.Sum(nil)), nil
}

type contextReader struct {
	ctx    context.Context
	reader io.Reader
}

func (r contextReader) Read(p []byte) (int, error) {
	if err := r.ctx.Err(); err != nil {
		return 0, err
	}
	return r.reader.Read(p)
}

func syncPath(root *os.Root, path string) error {
	file, err := root.Open(path)
	if err != nil {
		return err
	}
	return errors.Join(file.Sync(), file.Close())
}
