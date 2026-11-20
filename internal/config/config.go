package config

import (
	"github.com/alexfalkowski/einblick/internal/duckdb"
	"github.com/alexfalkowski/einblick/internal/health"
	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/go-service/v3/config"
)

// Config for the service.
type Config struct {
	// Queries configures required server-side limits for recent-log reads.
	Queries *storage.Config `yaml:"queries,omitempty" json:"queries,omitempty" toml:"queries,omitempty" validate:"required"`

	// DuckDB configures the required local file and native engine resources.
	DuckDB *duckdb.Config `yaml:"duckdb,omitempty" json:"duckdb,omitempty" toml:"duckdb,omitempty" validate:"required"`

	// Health configures the required service health checks and observers.
	Health *health.Config `yaml:"health,omitempty" json:"health,omitempty" toml:"health,omitempty" validate:"required"`

	// Config contains the required shared transport and telemetry configuration.
	*config.Config `yaml:",inline" json:",inline" toml:",inline" validate:"required"`
}

func decorateConfig(cfg *Config) *config.Config {
	return cfg.Config
}

func healthConfig(cfg *Config) *health.Config {
	return cfg.Health
}

func duckdbConfig(cfg *Config) *duckdb.Config {
	return cfg.DuckDB
}

func queryConfig(cfg *Config) *storage.Config {
	return cfg.Queries
}
