package static

import "github.com/alexfalkowski/go-signal/v2"

// Module installs the routes for the site's embedded CSS and JavaScript.
var Module = signal.Module(
	signal.Decorate(assetFunctions),
	signal.Register(Register),
)
