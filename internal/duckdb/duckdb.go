package duckdb

import (
	"net/url"
	"strconv"

	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/database/sql"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-signal/v2"
	_ "github.com/duckdb/duckdb-go/v2" // Register DuckDB for the shared SQL opener.
)

// Open opens the configured database, checks connectivity at lifecycle startup
// and closes it on shutdown. The caller must supply validated configuration.
// DuckDB manages the adjacent WAL and spill directory on the same writable path.
func Open(lifecycle signal.Lifecycle, cfg *Config) (*sql.DB, error) {
	settings := url.Values{
		"memory_limit": {cfg.MemoryLimit},
		"threads":      {strconv.Itoa(cfg.Threads)},
	}
	database, err := sql.Open("duckdb", strings.Concat(cfg.Path, "?", settings.Encode()))
	if err != nil {
		return nil, err
	}

	lifecycle.Append(signal.Hook{
		OnStart: database.PingContext,
		OnStop: func(_ context.Context) error {
			return database.Close()
		},
	})

	return database, nil
}
