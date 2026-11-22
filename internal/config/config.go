package config

import (
	"github.com/alexfalkowski/einblick/internal/duckdb"
	"github.com/alexfalkowski/einblick/internal/health"
	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/einblick/internal/logs/storage"
	"github.com/alexfalkowski/einblick/internal/r2"
	"github.com/alexfalkowski/go-service/v3/config"
)

// Config for the service.
type Config struct {
	// Archive enables local Parquet staging and optional R2 archival.
	Archive *ArchiveConfig `yaml:"archive,omitempty" json:"archive,omitempty" toml:"archive,omitempty"`

	// Queries configures required server-side limits for log reads.
	Queries *storage.Config `yaml:"queries,omitempty" json:"queries,omitempty" toml:"queries,omitempty" validate:"required"`

	// DuckDB configures the required local file and native engine resources.
	DuckDB *duckdb.Config `yaml:"duckdb,omitempty" json:"duckdb,omitempty" toml:"duckdb,omitempty" validate:"required"`

	// Health configures the required service health checks and observers.
	Health *health.Config `yaml:"health,omitempty" json:"health,omitempty" toml:"health,omitempty" validate:"required"`

	// Config contains the required shared transport and telemetry configuration.
	*config.Config `yaml:",inline" json:",inline" toml:",inline" validate:"required"`
}

// ArchiveConfig composes staging and publication settings under archive.
type ArchiveConfig struct {
	// R2 enables publication and historical reads when present.
	R2 *r2.Config `yaml:"r2,omitempty" json:"r2,omitempty" toml:"r2,omitempty"`

	// Config is required when the archive section enables local staging.
	archive.Config `yaml:",inline" json:",inline" toml:",inline"`
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

func archiveConfig(cfg *Config) *archive.Config {
	if cfg.Archive == nil {
		return nil
	}
	return &cfg.Archive.Config
}

func r2Config(cfg *Config) *r2.Config {
	if cfg.Archive == nil {
		return nil
	}
	return cfg.Archive.R2
}
