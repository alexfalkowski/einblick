package cmd

import (
	"github.com/alexfalkowski/einblick/internal/config"
	"github.com/alexfalkowski/einblick/internal/health"
	"github.com/alexfalkowski/go-service/v3/module"
	"github.com/alexfalkowski/go-signal/v2"
)

// Module composes the server, configuration, and health modules.
var Module = signal.Module(
	module.Server,
	config.Module,
	health.Module,
)
