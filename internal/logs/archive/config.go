package archive

import (
	"github.com/alexfalkowski/go-service/v3/bytes"
	"github.com/alexfalkowski/go-service/v3/time"
)

// Config enables periodic local Parquet export when present.
type Config struct {
	// Workspace is an existing writable staging directory on a separate, quota-limited filesystem.
	Workspace string `yaml:"workspace" json:"workspace" toml:"workspace" validate:"required"`

	// Interval is the period between export attempts. Runs never overlap.
	Interval time.Duration `yaml:"interval" json:"interval" toml:"interval" validate:"gt=0"`

	// BatchSize targets the uncompressed projected bytes per batch. It accepts
	// a positive decimal size string such as "65536B".
	// A single larger accepted row gets its own batch.
	BatchSize bytes.Size `yaml:"batch_size" json:"batch_size" toml:"batch_size" validate:"gt=0"`
}
