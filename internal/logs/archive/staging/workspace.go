package staging

import (
	"crypto/sha256"
	"encoding/hex"

	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/crypto/rand"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/io"
	"github.com/alexfalkowski/go-service/v3/os"
	"github.com/alexfalkowski/go-service/v3/strings"
)

const (
	pendingDir    = ".pending"
	partialName   = ".logs.parquet.partial"
	directoryMode = 0o700
)

// Keep at least 128 bits of randomness when the filesystem folds case.
const attemptNameLength = 26

// NewWorkspace manages local archive files under the configured workspace.
// A nil cfg disables staging.
func NewWorkspace(cfg *archive.Config, writer archive.BatchWriter, fs *os.FS, generator *rand.Generator) archive.StagedFiles {
	if cfg == nil {
		return nil
	}

	return &workspace{path: fs.Join(cfg.Workspace, archive.Version), writer: writer, fs: fs, generator: generator}
}

type workspace struct {
	writer    archive.BatchWriter
	prepared  os.FileInfo
	fs        *os.FS
	generator *rand.Generator
	path      string
}

// Prepare opens or initializes the export directory and clears interrupted output.
func (w *workspace) Prepare() error {
	if err := w.fs.Mkdir(w.path, directoryMode); err != nil && !errors.Is(err, io.ErrExist) {
		return errors.Prefix("log archive workspace", err)
	}

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
	file, _, err := w.OpenVerified(ctx, b)
	if file == nil {
		return false, err
	}
	return true, file.Close()
}

// OpenVerified checks the file opened through the workspace and rewinds it for upload.
func (w *workspace) OpenVerified(ctx context.Context, b archive.StagedBatch) (io.ReadCloser, int64, error) {
	root, info, err := w.openWorkspace()
	if err != nil {
		return nil, 0, err
	}
	defer root.Close()

	file, err := root.Open(b.Path())
	if err != nil {
		if errors.Is(err, io.ErrNotExist) {
			return nil, 0, w.checkWorkspace(info)
		}
		return nil, 0, err
	}

	checksum, size, err := checksumFile(ctx, file)
	if workspaceErr := w.checkWorkspace(info); workspaceErr != nil {
		return nil, 0, errors.Join(workspaceErr, file.Close())
	}
	if err != nil || checksum != b.Checksum {
		return nil, 0, errors.Join(err, file.Close())
	}
	if _, err := file.Seek(0, 0); err != nil {
		return nil, 0, errors.Join(err, file.Close())
	}
	return file, size, nil
}

// Remove unlinks a confirmed file from the prepared workspace. It is safe to retry.
func (w *workspace) Remove(b archive.Batch) error {
	root, info, err := w.openWorkspace()
	if err != nil {
		return err
	}
	defer root.Close()

	path := b.Path()
	if err := root.Remove(path); err != nil && !errors.Is(err, io.ErrNotExist) {
		return err
	}

	err = syncPath(root, w.fs.Dir(path))
	if errors.Is(err, io.ErrNotExist) {
		err = nil
	}
	return errors.Join(err, w.checkWorkspace(info))
}

// Stage writes, verifies and publishes one completed file. It returns the file
// checksum for the caller to record in durable batch state.
func (w *workspace) Stage(ctx context.Context, b archive.Batch) (_ string, err error) {
	root, info, err := w.openWorkspace()
	if err != nil {
		return strings.Empty, err
	}
	defer root.Close()

	name, err := w.generator.GenerateText(attemptNameLength)
	if err != nil {
		return strings.Empty, err
	}

	destination := b.Path()
	day := w.fs.Dir(destination)

	// A pending batch can have a final filename after an interrupted rename
	// or a checksum mismatch. Its retained rows remain authoritative.
	if err := root.Remove(destination); err != nil && !errors.Is(err, io.ErrNotExist) {
		return strings.Empty, err
	}

	if err := root.MkdirAll(day, directoryMode); err != nil {
		return strings.Empty, err
	}

	// Only the verified workspace has this attempt's private directory.
	attempt := w.fs.Join(pendingDir, name)
	if err := root.Mkdir(attempt, directoryMode); err != nil {
		return strings.Empty, err
	}
	defer func() {
		err = errors.Join(err, root.RemoveAll(attempt))
	}()

	partial := w.fs.Join(attempt, partialName)
	if err := w.writer.WriteParquet(ctx, b, w.fs.Join(w.path, partial)); err != nil {
		return strings.Empty, err
	}

	checksum, err := w.publishFile(ctx, root, partial, destination)
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
	current, err := w.fs.Lstat(w.path)
	if err != nil {
		return errors.Prefix("log archive workspace", err)
	}

	if !w.fs.SameFile(current, opened) || (w.prepared != nil && !w.fs.SameFile(current, w.prepared)) {
		return errors.New("log archive workspace changed since startup")
	}

	return nil
}

func (w *workspace) publishFile(ctx context.Context, root *os.Root, partial, destination string) (string, error) {
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

	return checksum, syncPath(root, w.fs.Dir(destination))
}

func fileChecksum(ctx context.Context, root *os.Root, path string) (string, error) {
	file, err := root.Open(path)
	if err != nil {
		return strings.Empty, err
	}
	defer file.Close()

	checksum, _, err := checksumFile(ctx, file)
	return checksum, err
}

func checksumFile(ctx context.Context, file io.Reader) (string, int64, error) {
	hash := sha256.New()
	size, err := io.Copy(hash, contextReader{ctx: ctx, reader: file})
	return hex.EncodeToString(hash.Sum(nil)), size, err
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
