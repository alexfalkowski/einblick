package archive

import "github.com/alexfalkowski/go-service/v3/time"

// Config enables periodic local Parquet export when present.
type Config struct {
	// Workspace is an existing writable staging directory on a separate, quota-limited filesystem.
	Workspace string `yaml:"workspace" json:"workspace" toml:"workspace" validate:"required"`

	// Interval is the period between export attempts. Runs never overlap.
	Interval time.Duration `yaml:"interval" json:"interval" toml:"interval" validate:"gt=0"`
}
