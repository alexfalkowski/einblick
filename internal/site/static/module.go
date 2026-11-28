package static

import "github.com/alexfalkowski/go-signal/v2"

// Module installs the browser favicon route.
var Module = signal.Module(
	signal.Register(Register),
)
