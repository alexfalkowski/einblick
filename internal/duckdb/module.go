package duckdb

import "github.com/alexfalkowski/go-signal/v2"

// Module provides the local database to health checks and signal repositories.
var Module = signal.Module(
	signal.Constructor(Open),
)
