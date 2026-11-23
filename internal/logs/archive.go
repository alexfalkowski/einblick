package logs

import (
	"github.com/alexfalkowski/einblick/internal/duckdb"
	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/einblick/internal/r2"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/database/sql"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/os"
	"github.com/alexfalkowski/go-service/v3/time"
	"github.com/alexfalkowski/go-service/v3/transport/http"
	"github.com/alexfalkowski/go-service/v3/transport/http/retry"
	"github.com/alexfalkowski/go-signal/v2"
)

func newArchiveStore(lc signal.Lifecycle, cfg *r2.Config, db *sql.DB, fs *os.FS) (archive.ObjectStore, error) {
	if cfg == nil {
		return nil, nil //nolint:nilnil // R2 archives are optional.
	}

	options := []http.ClientOption{
		http.WithClientLifecycle(lc),
		http.WithClientFS(fs),
		http.WithClientRetry(retry.NewConfig(cfg.Client.Retry), retry.SafeMethods),
	}
	publication, endpoint, err := http.NewClientFromConfig(cfg.Client, options...)
	if err != nil {
		return nil, errors.Prefix("archive.r2.client", err)
	}

	discovery, _, err := http.NewClientFromConfig(cfg.Client, options...)
	if err != nil {
		return nil, errors.Prefix("archive.r2.client", err)
	}

	settings, err := cfg.Resolve(fs, endpoint, time.Duration(publication.Timeout))
	if err != nil {
		return nil, err
	}

	store, err := r2.NewStore(settings, publication, discovery)
	if err != nil {
		return nil, err
	}

	lc.Append(signal.Hook{OnStart: func(ctx context.Context) error {
		return duckdb.ConfigureR2(ctx, db, settings)
	}})
	return store, nil
}
