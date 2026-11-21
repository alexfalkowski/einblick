package storage

import "github.com/alexfalkowski/go-signal/v2"

// Module provides log and archive storage. The migrate package owns schema
// startup, and the duckdb package closes the connection.
var Module = signal.Module(signal.Constructor(NewRepository, NewArchive))
