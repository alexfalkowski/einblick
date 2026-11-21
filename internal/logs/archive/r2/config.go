package r2

import (
	"github.com/alexfalkowski/go-service/v3/net/url"
	"github.com/alexfalkowski/go-service/v3/time"
)

// Config describes the S3 endpoint and credentials for archive publication.
type Config struct {
	// Endpoint is the S3 API base URL. Local emulators may use loopback HTTP.
	Endpoint *url.SecureURL `yaml:"endpoint" json:"endpoint" toml:"endpoint" validate:"required"`

	// Bucket already exists and accepts reads and writes.
	Bucket string `yaml:"bucket" json:"bucket" toml:"bucket" validate:"required"`

	// Region is the signing region. Use "auto" for R2.
	Region string `yaml:"region" json:"region" toml:"region" validate:"required"`

	// AccessKeyID is a go-service source string read at startup.
	AccessKeyID string `yaml:"access_key_id" json:"access_key_id" toml:"access_key_id" validate:"required"`

	// SecretAccessKey is a go-service source string read at startup.
	SecretAccessKey string `yaml:"secret_access_key" json:"secret_access_key" toml:"secret_access_key" validate:"required"`

	// RequestTimeout bounds each S3 request including multipart abort.
	RequestTimeout time.Duration `yaml:"request_timeout" json:"request_timeout" toml:"request_timeout" validate:"gt=0"`
}
