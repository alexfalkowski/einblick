package logs

import (
	"github.com/alexfalkowski/einblick/internal/duckdb"
	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/einblick/internal/r2"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/database/sql"
	"github.com/alexfalkowski/go-service/v3/os"
	"github.com/alexfalkowski/go-signal/v2"
)

func newArchiveStore(lc signal.Lifecycle, cfg *r2.Config, db *sql.DB, fs *os.FS) (archive.ObjectStore, error) {
	if cfg == nil {
		return nil, nil //nolint:nilnil // R2 archives are optional.
	}

	store, err := r2.NewStore(cfg, fs)
	if err != nil {
		return nil, err
	}

	lc.Append(signal.Hook{OnStart: func(ctx context.Context) error {
		return duckdb.ConfigureR2(ctx, db, cfg, fs)
	}})
	return store, nil
}
