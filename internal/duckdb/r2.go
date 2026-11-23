package duckdb

import (
	"github.com/alexfalkowski/einblick/internal/r2"
	"github.com/alexfalkowski/go-service/v3/context"
	"github.com/alexfalkowski/go-service/v3/database/sql"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/strings"
	"github.com/alexfalkowski/go-service/v3/time"
)

// ConfigureR2 installs and loads httpfs and configures it for the archive bucket.
func ConfigureR2(ctx context.Context, db *sql.DB, settings *r2.BucketSettings) error {
	// Round the resolved HTTP client timeout up to whole seconds.
	timeout := int64((settings.Timeout-time.Nanosecond)/time.Second) + 1
	if _, err := db.ExecContext(ctx, configureHTTPFSQuery, timeout); err != nil {
		return err
	}

	endpoint := settings.Endpoint.URL()
	_, err := db.ExecContext(ctx, createR2SecretQuery, settings.AccessKeyID, settings.SecretAccessKey, settings.Region,
		strings.Concat(endpoint.Scheme, "://", endpoint.Host, endpoint.EscapedPath()),
		strings.Concat("s3://", settings.Bucket, "/"))
	if err != nil {
		// DuckDB errors can include values bound into the secret statement.
		return errors.New("configure DuckDB archive credentials")
	}
	return nil
}
