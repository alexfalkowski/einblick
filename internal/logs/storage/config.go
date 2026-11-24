package storage

import "github.com/alexfalkowski/go-service/v3/time"

// Config bounds log queries. Every setting is required.
type Config struct {
	// MaxResults is the largest page, and the page size when the caller omits it.
	MaxResults int `yaml:"max_results" json:"max_results" toml:"max_results" validate:"gt=0,lt=9223372036854775807"`

	// MaxRange is the maximum absolute event-time interval per query.
	MaxRange time.Duration `yaml:"max_range,omitempty" json:"max_range,omitempty" toml:"max_range,omitempty" validate:"gt=0"`

	// Timeout bounds queueing and database work together.
	Timeout time.Duration `yaml:"timeout,omitempty" json:"timeout,omitempty" toml:"timeout,omitempty" validate:"gt=0"`

	// Concurrency bounds active queries independently for local and archive searches.
	Concurrency int `yaml:"concurrency,omitempty" json:"concurrency,omitempty" toml:"concurrency,omitempty" validate:"gt=0"`
}
