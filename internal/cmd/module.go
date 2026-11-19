package cmd

import (
	"github.com/alexfalkowski/einblick/internal/config"
	"github.com/alexfalkowski/einblick/internal/health"
	"github.com/alexfalkowski/einblick/internal/logs"
	"github.com/alexfalkowski/einblick/internal/metrics"
	"github.com/alexfalkowski/einblick/internal/traces"
	"github.com/alexfalkowski/go-service/v3/module"
	"github.com/alexfalkowski/go-signal/v2"
)

// Module composes the server, configuration, health, and telemetry receiver modules.
var Module = signal.Module(
	module.Server,
	config.Module,
	health.Module,
	logs.Module,
	metrics.Module,
	traces.Module,
)
