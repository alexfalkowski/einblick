package r2

import (
	"github.com/alexfalkowski/go-service/v3/bytes"
	"github.com/alexfalkowski/go-service/v3/config/client"
	"github.com/alexfalkowski/go-service/v3/errors"
	"github.com/alexfalkowski/go-service/v3/net/url"
	"github.com/alexfalkowski/go-service/v3/os"
	"github.com/alexfalkowski/go-service/v3/time"
)

// Config describes the R2 bucket and its S3 connection settings.
type Config struct {
	// Client configures the required S3 API endpoint and HTTP transport.
	Client *client.Config `yaml:"client" json:"client" toml:"client" validate:"required"`

	// Bucket already exists and accepts reads and writes.
	Bucket string `yaml:"bucket" json:"bucket" toml:"bucket" validate:"required"`

	// Region is the signing region. Use "auto" for R2.
	Region string `yaml:"region" json:"region" toml:"region" validate:"required"`

	// AccessKeyID is a go-service source string read at startup.
	AccessKeyID string `yaml:"access_key_id" json:"access_key_id" toml:"access_key_id" validate:"required"`

	// SecretAccessKey is a go-service source string read at startup.
	SecretAccessKey string `yaml:"secret_access_key" json:"secret_access_key" toml:"secret_access_key" validate:"required"`

	// Retention mirrors the bucket's object-age expiration rule. Zero
	// leaves missing expected objects unavailable at any age.
	Retention time.Duration `yaml:"retention" json:"retention" toml:"retention" validate:"gte=0"`
}

// BucketSettings contains the resolved S3 settings shared by the archive store and DuckDB.
type BucketSettings struct {
	// Endpoint is the validated S3 API base URL.
	Endpoint *url.SecureURL

	// Bucket is the name of the existing archive bucket.
	Bucket string

	// Region is the S3 signing region.
	Region string

	// AccessKeyID is the resolved S3 access key ID.
	AccessKeyID string

	// SecretAccessKey is the resolved S3 secret access key.
	SecretAccessKey string

	// Timeout is the effective per-request timeout of the Go S3 client.
	Timeout time.Duration

	// Retention is the bucket's configured object-age expiration duration.
	Retention time.Duration
}

// Resolve loads the credential sources and combines them with the resolved HTTP settings.
func (c *Config) Resolve(fs *os.FS, endpoint *url.SecureURL, timeout time.Duration) (*BucketSettings, error) {
	accessKeyID, err := readCredential(fs, c.AccessKeyID)
	if err != nil {
		return nil, errors.Prefix("R2 access key ID", err)
	}

	secretAccessKey, err := readCredential(fs, c.SecretAccessKey)
	if err != nil {
		return nil, errors.Prefix("R2 secret access key", err)
	}

	return &BucketSettings{
		Endpoint:        endpoint,
		Bucket:          c.Bucket,
		Region:          c.Region,
		AccessKeyID:     accessKeyID,
		SecretAccessKey: secretAccessKey,
		Timeout:         timeout,
		Retention:       c.Retention,
	}, nil
}

func readCredential(fs *os.FS, source string) (string, error) {
	key, err := fs.ReadSource(source)
	if err == nil && len(key) == 0 {
		err = errors.New("credential source is empty")
	}
	return bytes.String(key), err
}
