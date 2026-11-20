package route

import "github.com/alexfalkowski/go-signal/v2"

// Module registers the Logs routes after their dependencies are available.
var Module = signal.Module(
	signal.Register(Register),
)
