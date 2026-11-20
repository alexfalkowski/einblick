package logs

import (
	"github.com/alexfalkowski/einblick/internal/site/logs/route"
	"github.com/alexfalkowski/go-signal/v2"
)

// Module installs the Logs feature on the shared site.
var Module = signal.Module(
	route.Module,
)
