package cmd

import (
	v1 "github.com/alexfalkowski/einblick/internal/api/v1"
	"github.com/alexfalkowski/einblick/internal/config"
	"github.com/alexfalkowski/einblick/internal/duckdb"
	"github.com/alexfalkowski/einblick/internal/health"
	"github.com/alexfalkowski/einblick/internal/logs"
	"github.com/alexfalkowski/einblick/internal/metrics"
	"github.com/alexfalkowski/einblick/internal/migrate"
	"github.com/alexfalkowski/einblick/internal/traces"
	"github.com/alexfalkowski/go-service/v3/module"
	"github.com/alexfalkowski/go-signal/v2"
)

// Module composes the server, configuration, database, health and telemetry receivers.
var Module = signal.Module(
	// Recovery hooks precede listener startup; shutdown drains listeners before
	// closing the shared database. Constructors are resolved by the shared graph.
	migrate.Module,
	module.Server,
	config.Module,
	duckdb.Module,
	health.Module,
	logs.Module,
	v1.Module,
	metrics.Module,
	traces.Module,
)
