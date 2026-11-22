package duckdb

import (
	"github.com/alexfalkowski/einblick/internal/r2"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/database/sql"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/os"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
)

// ConfigureR2 installs and loads httpfs and creates a temporary secret for the R2 archive bucket.
func ConfigureR2(ctx context.Context, db *sql.DB, cfg *r2.Config, fs *os.FS) error {
	accessKeyID, err := cfg.GetAccessKeyID(fs)
	if err != nil {
		return err
	}
	secretAccessKey, err := cfg.GetSecretAccessKey(fs)
	if err != nil {
		return err
	}

	// Round the validated positive timeout up to whole seconds.
	timeout := int64((cfg.RequestTimeout-time.Nanosecond)/time.Second) + 1
	if _, err := db.ExecContext(ctx, configureHTTPFSQuery, timeout); err != nil {
		return err
	}

	endpoint := cfg.Endpoint.URL()
	_, err = db.ExecContext(ctx, createR2SecretQuery, accessKeyID, secretAccessKey, cfg.Region,
		strings.Concat(endpoint.Scheme, "://", endpoint.Host, endpoint.EscapedPath()),
		strings.Concat("s3://", cfg.Bucket, "/"))
	if err != nil {
		// DuckDB errors can include values bound into the secret statement.
		return errors.New("configure DuckDB archive credentials")
	}
	return nil
}
