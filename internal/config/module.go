package config

import (
	"github.com/alexfalkowski/go-service/v3/config"
	"github.com/alexfalkowski/go-signal/v2"
)

// Module decodes service configuration and projects shared and health settings.
var Module = signal.Module(
	signal.Constructor(config.NewConfig[Config]),
	signal.Decorate(decorateConfig),
	signal.Constructor(healthConfig),
)
