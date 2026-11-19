package duckdb

import (
	"net/url"
	"strconv"

	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/database/sql"
	"github.com/alexfalkowski/go-service/v3/database/sql/telemetry"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/telemetry/attributes"
	"github.com/alexfalkowski/go-signal/v2"
	_ "github.com/duckdb/duckdb-go/v2" // Register DuckDB for the shared SQL opener.
)

// Open opens the configured database with SQL telemetry, checks connectivity at
// lifecycle startup and closes it and unregisters pool metrics on shutdown.
// The caller must supply validated configuration.
// DuckDB manages the adjacent WAL and spill directory on the same writable path.
func Open(lc signal.Lifecycle, cfg *Config) (*sql.DB, error) {
	settings := url.Values{
		"memory_limit": {cfg.MemoryLimit},
		"threads":      {strconv.Itoa(cfg.Threads)},
	}
	options := []telemetry.Option{telemetry.WithAttributes(attributes.DBSystemNameKey.String("duckdb"))}
	db, err := telemetry.Open("duckdb", strings.Concat(cfg.Path, "?", settings.Encode()), options...)
	if err != nil {
		return nil, err
	}

	registration, err := telemetry.RegisterDBStatsMetrics(db, options...)
	if err != nil {
		return nil, errors.Join(err, db.Close())
	}

	lc.Append(signal.Hook{
		OnStart: db.PingContext,
		OnStop: func(_ context.Context) error {
			return errors.Join(db.Close(), registration.Unregister())
		},
	})

	return db, nil
}
