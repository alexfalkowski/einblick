package logs

import "github.com/alexfalkowski/go-signal/v2"

// Module adapts the shared log repository to the v1 API contract.
var Module = signal.Module(
	signal.Constructor(NewService),
)
