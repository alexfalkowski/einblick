package query

import (
	"fmt"

	"github.com/alexfalkowski/go-service/v3/bytes"
	"github.com/alexfalkowski/go-service/v3/io"
	"github.com/alexfalkowski/go-service/v3/runtime"
	"github.com/alexfalkowski/go-service/v3/strings"
)

// Set holds the SQL text loaded from a filesystem. A Set can be shared across
// goroutines. Its zero value is empty.
type Set struct {
	statements map[string]string
}

// Load reads .sql files recursively under dir. It preserves their contents and
// keys them by slash-separated paths relative to the filesystem root.
func Load(fsys io.FS, dir string) (Set, error) {
	statements := make(map[string]string)
	err := io.WalkDir(fsys, dir, func(path string, entry io.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if entry.IsDir() || !strings.HasSuffix(path, ".sql") {
			return nil
		}

		data, err := io.ReadFile(fsys, path)
		if err != nil {
			return err
		}
		statements[path] = bytes.String(data)
		return nil
	})
	if err != nil {
		return Set{}, fmt.Errorf("load SQL in %q: %w", dir, err)
	}
	return Set{statements: statements}, nil
}

// MustLookup returns the SQL stored at path. It panics if the path is missing.
// Use it for SQL paths fixed in code.
func (s Set) MustLookup(path string) string {
	statement, ok := s.statements[path]
	if !ok {
		runtime.Must(&io.PathError{Op: "lookup SQL", Path: path, Err: io.ErrNotExist})
	}
	return statement
}
