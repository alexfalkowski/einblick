package storage

import (
	"github.com/alexfalkowski/einblick/internal/logs/archive"
	"github.com/alexfalkowski/go-signal/v2"
)

// Module provides log and archive storage. The migrate package owns schema
// startup, and the duckdb package closes the connection.
var Module = signal.Module(
	signal.Constructor(loadStatements, newRepository, newArchive, batchRepository, batchWriter, evictionRepository),
)

func batchRepository(store *Archive) archive.BatchRepository {
	return store
}

func batchWriter(store *Archive) archive.BatchWriter {
	return store
}

func evictionRepository(store *Archive) archive.EvictionRepository {
	return store
}
