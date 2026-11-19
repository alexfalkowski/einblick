package storage

import "github.com/alexfalkowski/go-signal/v2"

// Module provides the composed Repository. The migrate package owns schema startup,
// and the duckdb package owns and closes the shared connection.
var Module = signal.Module(signal.Constructor(NewRepository))
